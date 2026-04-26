# Linux notes

Platform-specific notes for the Linux composition workshop.

## What "Tier 0 always at the base" means in practice

Every example runner in `linux/` assumes the host shell that launched it has cred-scrub + direnv-perimeter applied. The runners do *not* re-scrub on their own. Here's what that looks like operationally:

```sh
# One-time setup
mkdir -p ~/sandbox-test
cp <repo>/topics/sandboxing/cred-scrub/linux/solution.envrc ~/sandbox-test/.envrc
cd ~/sandbox-test
direnv allow

# Now any runner you launch from this shell inherits the scrubbed env
bash <repo>/topics/sandboxing/composition/linux/compose-bwrap.sh
bash <repo>/topics/sandboxing/composition/linux/compose-docker.sh
bash <repo>/topics/sandboxing/composition/linux/compose-docker-egress.sh
```

If you run a composition from outside the perimeter, the inner sandbox layers still apply but the host shell isn't scrubbed — the agent's parent process has whatever your launching shell had. That's a meaningfully different threat profile from the matrix in `workshop.md`.

## Why each runner just delegates

The composition runners (`compose-bwrap.sh`, `compose-docker.sh`, `compose-docker-egress.sh`) are deliberately thin. Each prints the host's relevant Tier 0 state, then `exec`s into the underlying topic's runner. The composition workshop doesn't introduce new mechanism; it shows you how to read and stack what's already there.

If you want a more "interesting" composed runner — one that, say, takes a target directory and an agent command as arguments and wraps them in the right composition for a chosen scenario — that's a useful exercise to write yourself, with your LLM, after working through the discussion prompts.

## How `bwrap` and Docker compositions differ in practice

Both can produce nearly identical filesystem and network isolation. The differences that matter for choosing:

- **Spin-up time.** bwrap is fork+exec — a few milliseconds. Docker is image-pull-on-first-run plus container start — seconds at minimum.
- **Daemon footprint.** Docker requires a daemon running (or rootless's user-mode daemon). bwrap requires nothing.
- **Audit cost.** Docker's flags are well-known and widely documented; auditing a `docker run` invocation is easier for newcomers. bwrap's `--bind` semantics are more flexible but require more care.
- **Persistence model.** Docker has named volumes, build caches, image layers — all places state can live across "runs." bwrap leaves nothing behind unless you bind in a writable path.
- **Cross-platform.** Docker works on Mac/Windows (with Docker Desktop). bwrap is Linux-only.

For a one-shot agent invocation against an unfamiliar repo, bwrap is usually the right choice (faster, lighter, no daemon). For a long-running MCP server or a GUI tool that needs to persist some state, Docker is usually the right choice. The composition workshop's job is to make those trade-offs explicit, not to push one over the other.

## The implicit Tier 3 on Mac/Windows

A teaching point worth knowing for the talk: on Mac/Windows, when you use Docker Desktop, your "Tier 2 container" runs inside a Linux VM that Docker Desktop spins up. So Mac/Windows users get an *implicit* Tier 3 layer for free — the kernel attack surface row in the matrix is actually closed for them, even though they think they're at Tier 2.

That's a free defense Mac/Windows users have that Linux-native users don't. It's also the reason cross-platform performance comparisons are misleading (they're really comparing hypervisor overhead, not container overhead).

## Where the cracks are between layers

Composition can fail in subtle ways at the seams between layers:

- **`-e VAR` from a non-scrubbed parent.** If your host shell isn't actually scrubbed, `docker run -e GITHUB_TOKEN` passes whatever your shell had, which might be your prod token. The container looks hardened; the credential is real-and-broad.
- **`-v` bind-mounts cross the FS boundary.** Bind-mounting `~/.aws` defeats every other layer. Read every `-v` line.
- **`network_mode: "host"`** in compose silently undoes container network isolation. Same with `--network=host` on a `docker run`.
- **`--privileged`** undoes most of the cap-drop hardening. Almost no agent workload legitimately needs it.

When evaluating someone else's composed setup, scan for these four patterns first.
