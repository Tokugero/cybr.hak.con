# Workshop: container isolation

A hands-on exercise. You'll run two probes — the cred-scrub probe you already know, plus a new container-shape probe — both on the host and inside two different containers, and watch what changes.

Substitute `<repo>` for the path to your clone. Linux paths only for now; Mac and Windows are pending in `PORTING.md`.

## 1. What a container actually is

A container is a process (or process group) running in its own set of Linux namespaces — its own filesystem view, its own process IDs, its own mount table, optionally its own network stack and user IDs. **The kernel is shared with the host.**

Two consequences:

- *Filesystem is fresh.* The container can only see files that came from its image, plus anything you bind-mount in. Your `~/.aws`, `~/.kube`, `~/.ssh` aren't there unless you put them there.
- *Kernel is shared.* A kernel CVE that escapes namespaces is a container escape. Pair with Tier 3 (a VM) if your threat model includes kernel-level attackers.

If you're on Mac or Windows, your container engine (Docker Desktop) is itself running a Linux VM in the background. So when this workshop talks about "the container," you're really running container-in-a-VM. The container-side security model is identical; the kernel that's "shared" is the VM's, not your host's. Different threat model, but tangential to this exercise.

## 2. Run the probes on the host (baseline)

You've seen the cred-scrub probe before. Run it now to remind yourself of what your shell exposes today:

```sh
bash <repo>/topics/sandboxing/cred-scrub/linux/probe.sh
```

Then run the new container-shape probe:

```sh
bash <repo>/topics/sandboxing/container-isolation/linux/container-probe.sh
```

The container-probe reports your `uid`, whether you're inside a container at all, your Linux capabilities, your network namespace state, your root filesystem writability, and whether the docker socket is reachable. On the host with Docker installed, you'll see something like:

- `uid` = your real user ID (probably non-zero)
- `container` = `no`
- `Capabilities` = depends on your shell
- `Network namespace` = `active` (you have your usual interfaces)
- `Root filesystem` = `writable`
- `Docker socket` = `reachable` (because Docker is running on this host)

Save that output. We'll diff against it.

## 3. Run the probes inside a *default* Docker container

```sh
bash <repo>/topics/sandboxing/container-isolation/linux/run-default.sh
```

This script launches `docker run --rm -v <sandboxing-dir>:/workshop:ro ubuntu:24.04 bash -c '<both probes>'`. No hardening flags. All Docker defaults.

Look at the output and compare against step 2:

**The cred-scrub probe shows your credentials are mostly gone.** That's the headline Tier 2 effect on credential reach: the container's filesystem doesn't include your dotfiles. `~/.aws`, `~/.kube`, `~/.ssh` — none of them are there.

**The container-shape probe shows the *defaults* aren't great.** In a default Docker container:

- `uid` = `0` (root inside the container).
- `container` = detected (a `/.dockerenv` exists).
- `Capabilities` = a non-zero default set Docker grants. Includes things like `CAP_NET_RAW`, `CAP_CHOWN`, `CAP_SETUID`, etc.
- `Network namespace` = active, with the default Docker bridge — meaning the container has internet access, can resolve DNS, can `curl evil.com`.
- `Root filesystem` = `writable`.

That's the "default Docker is weaker than people think" claim, made visible. Filesystem isolation works; kernel-, capability-, and network-isolation are not enabled by default. An agent inside this container is root, can install things, can reach the network, can do most of what its capabilities allow.

## 4. Run the probes inside a *hardened* container

```sh
bash <repo>/topics/sandboxing/container-isolation/linux/run-hardened.sh
```

Same image, but with a list of hardening flags:

- `--user=$(id -u):$(id -g)` — run as your host user, not root in the container.
- `--network=none` — no network at all (no bridge, no DNS, no nothing).
- `--read-only` — root filesystem mounted read-only.
- `--tmpfs /tmp` — give the container a writable `/tmp` (some tools need it).
- `--cap-drop=ALL` — drop every Linux capability.
- `--security-opt=no-new-privileges` — prevent setuid escalation.

Compare against step 3:

- `uid` = your host user ID (not 0).
- `Capabilities` = `all dropped`. Things like `ping` (which needs `CAP_NET_RAW`) fail.
- `Network namespace` = `isolated` — no curl, no DNS.
- `Root filesystem` = `read-only`.
- `Docker socket` = `absent` (we never mounted it).

This is the *fair* Tier 2 demonstration. The default Docker container was closer to "shell with a different home directory." This one has actual isolation in the dimensions agents care about most.

## 5. Compose with Tier 0 — passing scoped credentials in

The agent inside the hardened container has zero credentials, but you also can't do useful work with zero credentials. The composition pattern is: keep the host shell scrubbed (cred-scrub + direnv-perimeter), fetch one narrow credential into a variable, and pass *the value* in via `--env`:

```sh
# Right: pass the value as an env var
GITHUB_TOKEN="$(scoped-token-fetcher)" docker run --rm \
  -e GITHUB_TOKEN \
  --user="$(id -u):$(id -g)" \
  --network=none --read-only --tmpfs /tmp \
  --cap-drop=ALL --security-opt=no-new-privileges \
  -v "$(pwd):/work:ro" \
  ubuntu:24.04 \
  bash -c 'do-the-thing'
```

What you should *not* do:

```sh
# Wrong: bind-mount your home — re-introduces all your credentials
docker run -v "$HOME":/host-home ...

# Wrong: bind-mount the docker socket — gives the container host control
docker run -v /var/run/docker.sock:/var/run/docker.sock ...

# Wrong: --network=host — undoes the network isolation
docker run --network=host ...
```

Each of these patterns shows up in real-world `docker run` invocations because they make some convenience work. They also each undo a major part of what Tier 2 was supposed to do. If you see them in an `.envrc` or runner script you didn't write, ask why.

## 6. Honest gaps

What containers — even hardened ones — don't address:

- **Kernel attack surface.** Containers share the kernel with the host (or with the VM, on Mac/Windows). A kernel CVE that escapes namespaces is a container escape. If your threat model includes kernel-level attackers, you want Tier 3.
- **Docker socket access.** Anything that can talk to `/var/run/docker.sock` can launch privileged containers and effectively own the host. Never mount this socket into a container the agent runs in. Some "developer convenience" tooling does this without warning; verify before allowing.
- **Bind-mounted volumes.** Whatever you `-v` in is reachable. The container's "isolation" only covers what's NOT mounted.
- **GUI passthrough.** If you mount Wayland or X11 sockets to make GUI tools work inside the container, your "container" can keylog, screenshot, and inject input across that boundary. (See the survey doc's claucker breakdown for a real-world example of this trade-off.)
- **Image trust.** A poisoned base image runs as you intended. `ubuntu:24.04` from Docker Hub is widely trusted; a random `username/sketchy-image:latest` is not. Pin to specific image digests for serious work.
- **Long-lived containers with persistent volumes.** Anything written to a named volume persists across restarts. That's S4 (persistence) by design — fine if it's what you wanted, problematic if you forgot.

## 7. Where to next

`discussion.md` has prompts to ask your LLM:

- "Walk me through the difference between `--user=$(id -u):$(id -g)` and rootless Docker. What does each one address that the other doesn't?"
- "What's the threat model where `--network=none` is overkill, and what's the one where it's the minimum I should accept?"
- "If I'm on Mac and the container is already in a Linux VM, do I still need `--cap-drop=ALL`? Walk me through what changes about the threat model."
- "Sketch a `docker run` invocation that lets me run a Claude Code subagent against an unfamiliar repo, with cred-scrub + container hardening composed correctly."

Tier 3 (full virtualization) is the next step up the ladder when it's ready as a topic in this track.
