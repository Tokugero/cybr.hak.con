# Container isolation

A workshop on Tier 2 sandboxing: running an AI coding agent inside a container so the host filesystem, network, and credentials are out of reach.

## What you'll learn

- What containers actually isolate (separate filesystem, process, mount, and network namespaces) versus what they don't (shared kernel, mounted volumes, default network access).
- How a *default* Docker container differs from a *hardened* one — and why "default Docker is weaker than people think" is a load-bearing claim for this topic.
- How to compose Tier 2 with Tier 0: pass a scoped credential into the container, don't bind-mount your home directory.
- The honest gaps containers don't address: kernel attack surface, docker socket leaks, GUI passthrough, persistent volumes.

## Threats addressed

- **S1 (credential exfiltration)** — the container starts with a fresh filesystem; your `~/.aws`, `~/.kube`, `~/.ssh` aren't reachable unless you mount them in.
- **S2 (supply chain via add-ons)** — a malicious MCP server running inside the container can't trivially read your host home; the worst case is bounded by the mount and network configuration.
- **S3 (scope creep)** — the agent's "summarize my project" task can't accidentally read `~/Documents/taxes/` because the container doesn't have it mounted.

What this topic doesn't address fully:
- **S4 (persistence)** — depends on whether you use named volumes or `--rm`. Default ephemeral containers go away cleanly; mounted volumes persist whatever was written.

For the full threat model and tier vocabulary, see `../README.md`.

## Relationship to cred-scrub and direnv-perimeter

This topic **builds on** Tier 0 hygiene. Containers compose with cred-scrub and direnv-perimeter — you can (and should) scrub the host shell *before* launching the container, then pass narrow scoped credentials in through env vars. Doing one without the other leaves a gap in the corresponding direction.

## What you need

- A shell (bash/zsh on Mac/Linux/WSL).
- **Docker** — see `../../REQUIREMENTS.md` for install pointers. Tested with Docker 24+ on Linux. Mac/Windows uses Docker Desktop.
- An internet connection on first run, to pull `ubuntu:24.04` (~30MB).

## Time

- Surface pass: ~20 minutes.
- Including hardened-vs-default comparison and discussion: up to ~75.

## Layout

```
README.md                 — this file
workshop.md               — the exercise
discussion.md             — questions to ask your LLM after the workshop
PORTING.md                — handoff doc for adding Mac and Windows
linux/
  container-probe.sh      — reports container shape (uid, caps, ns, mounts)
  run-default.sh          — runs probes inside a default Docker container
  run-hardened.sh         — runs probes inside a hardened Docker container
  notes.md                — Linux-specific notes
  tests/run.sh            — verifies hardened > default on key dimensions
```

WSL users follow the Linux folder. Mac and Windows aren't built yet — see `PORTING.md`.
