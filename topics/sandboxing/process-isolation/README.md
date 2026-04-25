# Process-level isolation

A workshop on Tier 1 sandboxing: running an AI coding agent (or any untrusted process) in a Linux process sandbox where you explicitly choose what files, network, and resources are reachable. No daemon, no image, no overhead — just a wrapped exec.

## What you'll learn

- The difference between *process-level* isolation (Tier 1) and *container* isolation (Tier 2). Same underlying primitives (Linux namespaces, capability dropping); different ergonomics.
- How `bubblewrap` (`bwrap`) works on Linux — what the bind-mount flags do, when `--unshare-*` matters, what the trust model looks like.
- Why a permissive bwrap (lots bound, network shared) gives you basically nothing, while a hardened one gives you a tighter sandbox than default Docker for many use cases.
- How to compose Tier 1 with Tier 0: scrub the host shell, then bwrap the agent into a minimal view.

## Threats addressed

- **S1 (credential exfiltration)** — file scope is whatever you bind. With nothing bound, the agent can't read your dotfiles.
- **S3 (scope creep)** — same idea: you explicitly choose what's visible.
- **S4 (persistence)** — `--unshare-pid` plus a tmpfs `/tmp` and an unwritable `/`, the agent has no path to write something the host will execute later, *if* the binds are right.

What this topic doesn't address:
- **Kernel attack surface** — same shared-kernel limit as containers. A kernel CVE that escapes namespaces escapes bwrap too.
- **S2 (supply chain)** — bwrap doesn't help if the malicious code is *what you're already running*. It limits what that code can reach, not what can run.

For the full threat model, see `../README.md`.

## Why bother with Tier 1 if Tier 2 exists?

Two reasons that matter for agent workflows:

- **No daemon, no image.** No `docker pull`, no compose stack to manage, no socket to gate. `bwrap` is `fork → exec → done`. Spinning up an isolated process is essentially free.
- **Explicit control.** With `bwrap` you choose every directory, every device, every capability. With Docker you accept the image's view and patch it with `-v`. For "wrap one command tightly" Tier 1 is faster to write and easier to audit.

The trade-off: bwrap is Linux-specific (Mac and Windows have different process-isolation tools that aren't 1:1). For cross-platform agent workflows, Tier 2 stays more portable.

## What you need

- A Linux host (or WSL 2). Mac and Windows have analogous tools (`sandbox-exec` and AppContainer respectively); see `PORTING.md`.
- `bubblewrap`. Install via your package manager:
  - Debian/Ubuntu: `apt install bubblewrap`
  - Arch: `pacman -S bubblewrap`
  - Fedora: `dnf install bubblewrap`
  - NixOS: `nix-env -iA nixpkgs.bubblewrap` or `nix shell nixpkgs#bubblewrap`
- User namespaces enabled in the kernel (the default on most distros). If `unshare -U /bin/true` fails on your machine, your kernel has them disabled and bwrap won't work.

The probe script is the same `cred-scrub/linux/probe.sh` you used in earlier workshops — we mount it into the sandbox and run it inside.

## Time

- Surface pass: ~15 minutes.
- Including the discussion prompts and going-further: ~45.

## Layout

```
README.md              — this file
workshop.md            — the exercise
discussion.md          — questions to ask your LLM
PORTING.md             — handoff doc for Mac (sandbox-exec) and Windows (AppContainer)
linux/
  bwrap-permissive.sh  — bwrap with most things bound (deliberate weak example)
  bwrap-hardened.sh    — bwrap with minimal binds (the fair Tier 1 demo)
  notes.md             — Linux-specific notes (NixOS path notes, capability behavior)
  tests/run.sh         — verifies hardened > permissive on filesystem reachability
```

WSL users follow the Linux folder. Mac and Windows aren't built — see `PORTING.md`.
