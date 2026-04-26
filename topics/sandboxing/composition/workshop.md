# Workshop: composition

Three runner scripts, three different stackings, one matrix showing what each addresses.

## 1. The starting point — Tier 0 is always the base

Whatever you compose above it, **the host shell that launches the sandboxed process should already have the cred-scrub + direnv-perimeter setup applied**. That means:

- Cred-scrub `.envrc` has unset broad credentials and redirected default config paths to `/dev/null` or empty dirs.
- Direnv-perimeter (if used) has injected scoped narrow credentials for this work.
- Direnv has fired (you launched your terminal *inside* the perimeter, or you used `direnv exec`).

If your host shell has prod tokens loaded, every layer above is at risk of inheriting them. Tier 0 is not optional just because you're using a container or a VM.

For the rest of the workshop, assume your host shell is in a properly-loaded perimeter. (If you skipped cred-scrub and direnv-perimeter, go do those first.)

## 2. Pick a Tier 1+ layer — three runners to compare

The three example runners in `linux/` show distinct compositions:

### `compose-bwrap.sh` — Tier 0 + Tier 1

Wraps the cred-scrub probe in a hardened bwrap. No daemon, no image. Fastest to spin up. Linux-only.

Run it:
```sh
bash linux/compose-bwrap.sh
```

What it tells you: this is the **lightest possible isolation**. Good for one-shot agent commands where you want filesystem and network isolation without the overhead of a container daemon. Limitations: Linux-only, kernel attack surface shared, GUI tools awkward.

### `compose-docker.sh` — Tier 0 + Tier 2

Wraps the cred-scrub probe in a hardened Docker container (`--user`, `--network=none`, `--read-only`, `--cap-drop=ALL`). Slower (image pull, container start) but portable.

Run it:
```sh
bash linux/compose-docker.sh
```

What it tells you: this is the **portable hardened sandbox**. The same invocation works on Mac and Windows (with Docker Desktop). Heavier per-invocation than bwrap but easier to audit because the flags are well-known.

### `compose-docker-egress.sh` — Tier 0 + Tier 2 + network-egress

Brings up the gluetun + worker compose stack from network-egress, runs the cred-scrub probe and an egress probe inside the worker. Without VPN credentials, the worker is fail-closed on network.

Run it:
```sh
bash linux/compose-docker-egress.sh
```

What it tells you: this is the **strongest first-pass composition** for an agent doing untrusted work that needs no internet. Adds the network-axis lock to the filesystem axis. Heaviest setup of the three.

## 3. The matrix — what each composition addresses

| | Tier 0 alone | T0 + bwrap | T0 + Docker | T0 + Docker + egress |
|---|:---:|:---:|:---:|:---:|
| S1 (cred exfil via env) | ✓ | ✓ | ✓ | ✓ |
| S1 (cred exfil via dotfile read) | partial | ✓ | ✓ | ✓ |
| S1 (cred exfil via HTTP) | ⨯ | depends | depends | ✓ |
| S2 (supply chain via add-on) | ⨯ | partial | partial | partial |
| S3 (scope creep on benign tasks) | partial | ✓ | ✓ | ✓ |
| S4 (persistence) | ⨯ | ⨯ if --tmpfs `/tmp`, else partial | ✓ if `--rm`, else partial | ✓ if `--rm`, else partial |
| Kernel attack surface | ⨯ | ⨯ | ⨯ | ⨯ |
| Mac/Windows portability | ✓ | ⨯ (Linux only) | ✓ | ✓ |

Reading the matrix:

- **S1 cred-via-env** is closed by Tier 0 alone. The other layers don't add to it because the env was already clean.
- **S1 cred-via-dotfile-read** needs Tier 1+ — the file has to be unreachable, not just absent from the env.
- **S1 cred-via-HTTP** specifically needs network-egress control (the rightmost column). Filesystem isolation doesn't address an exfil that happens over the network.
- **S4 (persistence)** depends on whether the sandbox is ephemeral. `--rm` for Docker, `--die-with-parent` for bwrap, no persistent volumes / writable home, etc.
- **Kernel attack surface** is the same `⨯` across all the columns up to Tier 2. Only a VM (Tier 3, future topic) closes it.

## 4. Picking the right composition for a scenario

Walk through three scenarios from the talk:

### Scenario A — your own code, agent helps you edit

Trust: high. Reach: dev tier. Composition: **Tier 0 alone**. Adding bwrap or Docker here is over-engineering — you're paying complexity tax against a threat that's mostly accidental scope creep, and Tier 0 hygiene + the agent's own permission system already handles that. Over-sandboxing this case is the most common reason people give up and disable the sandbox entirely.

### Scenario B — agent processes untrusted content

Trust: semi-trusted execution. Reach: dev tier. Composition: **T0 + Docker**, plus the network-egress sidecar if the agent needs to fetch anything. The threat is S1 (HTTP exfil from a poisoned context) and S2 (a malicious tool the agent might invoke). Filesystem and network isolation both matter.

### Scenario D — agent against an unfamiliar codebase

Trust: untrusted code. Reach: dev tier. Composition: **T0 + Docker** with no network, or **T0 + bwrap with --unshare-net**. The threat is the codebase itself — postinstall scripts, `.envrc` files in the cloned repo (this is exactly why the `direnv-perimeter` workshop is worth its weight), git hooks. You want to clone, then run *nothing* until you're inside an isolated environment.

### Scenario F — agent has production credentials in scope

Trust: any. Reach: prod. Composition: **don't, mostly**. If you must, the sandbox isn't your primary control — credential scoping is. Compose Tier 0 (scoped time-boxed creds via `aws-vault exec` or equivalent) with Tier 2 hardened (Docker, no network unless explicitly needed). If your agent is doing prod work, the answer is usually "run this in a different account on a different machine entirely" (Tier 4), not "harder sandbox on my laptop."

For the rest of the talk's scenarios (C, E, G, H), apply the same trust-and-reach logic to the matrix above.

## 5. Reading a setup to evaluate it

A useful skill from this workshop is **reading** a sandbox setup someone else wrote and telling what threats it addresses. Try it on these:

```sh
# Setup A
docker run --rm -it -v "$HOME":/home/agent -v /var/run/docker.sock:/var/run/docker.sock --network=host ubuntu:24.04 bash
```

This is a worst-case "developer convenience" Docker invocation. What does it isolate?

(Answer: almost nothing. The home dir is bound, the docker socket is bound, the network is host. Filesystem reach is the agent's own home. Network is the host's. The agent can spawn privileged containers via the docker socket. This is closer to "shell with extra steps" than to a sandbox.)

```sh
# Setup B
bwrap --bind / / --unshare-net bash
```

(Answer: only network is unshared. Everything filesystem is still reachable because of `--bind / /`. This is a partial Tier 1 — filesystem isolation absent, network isolation present.)

```sh
# Setup C — the network-egress topic's docker-compose
# (gluetun sidecar + worker with network_mode: service:gluetun)
```

(Answer: filesystem inside the worker is whatever the worker image has plus mounted volumes. Network is whatever gluetun routes — fail-closed without credentials. Combined with cred-scrub + direnv-perimeter on the host, this is a strong S1 + S2 + S3 composition.)

The workshop's exercise: for any new setup you read or write, walk through the matrix and see what each layer addresses.

## 6. Honest gaps

- **Tier 3 (VMs) isn't here yet.** A composition with a full VM closes kernel attack surface — the one row above where every Tier 2 column has `⨯`. Worth knowing what you'd reach for if your threat model includes kernel-level attackers.
- **Tier 4 (separate user/machine/account) sometimes is the right answer.** If you wouldn't run an agent on your laptop at all, "harder sandbox on my laptop" is the wrong question. The composition workshop is about what to do when you've decided the laptop is the right place; that decision is upstream.
- **The agent's own permission system is its own axis.** Claude Code's allowlist, MCP server scoping, the agent's tool definitions — none of these are in the matrix above because they're orthogonal to OS isolation. A well-scoped agent inside a leaky sandbox can be safer than a permissive agent inside a hardened one. Compose both.
- **You're still trusting the human.** A poisoned `.envrc` you allowed, a Dockerfile you didn't read, a compose stack with `:latest` tags from an unverified registry — the trust gate is the human reviewing the setup. None of the compositions help against a human who skips that step.

## 7. Where to next

`discussion.md` has prompts for thinking through specific compositions with your LLM, including writing one for your own scenario. The talk's matrix (tier × scenario) is built from the same kind of reasoning the matrix in §3 above demonstrates — populating that matrix is what the talk's central visual does.
