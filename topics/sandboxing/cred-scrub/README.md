# Credential scrubbing

A workshop on Tier 0 hygiene: keeping credentials out of your agent's reach by cleaning your shell environment before the agent runs.

## What you'll learn

- What credentials are typically reachable from a default shell — and what's reachable on *your* shell right now.
- How to write a `.envrc` (or PowerShell profile) that does two things:
  1. Strips credential values from your environment when you `cd` in.
  2. Redirects default config paths (`KUBECONFIG`, `AWS_CONFIG_FILE`, `TALOSCONFIG`, etc.) so tools can't fall back to disk defaults like `~/.kube/config`.
- The honest limits: what scrubbing addresses, and what it doesn't.

## Threat addressed

Mostly **S1 — credential exfiltration via poisoned context**, in its accidental-exposure form. Your agent reads a poisoned file, the content tells it to send `~/.aws/credentials` somewhere, and your prod tokens leak. Scrubbing won't stop a malicious read of credentials that *are* present — it stops the *automatic* discovery paths from finding them in the first place.

For the full threat model and tier vocabulary, see `../README.md`.

## What you need

- A shell: `bash` or `zsh` on Mac/Linux/WSL, or PowerShell 7+ on Windows.
- `direnv`. [Installation](https://direnv.net/docs/installation.html). Free, popular, in every major package manager.

The test harness is a plain shell script (bash on Mac/Linux, PowerShell on Windows) — no extra dependency.

## Time

- Surface pass: ~10 minutes.
- Including discussion and the deep notes: up to ~60.

The workshop is drop-in/drop-out. Stop wherever; come back later.

## Layout

```
README.md          — this file
workshop.md        — the exercise
categories.md      — what credentials we cover (cross-platform reference, with Layer 1 vs Layer 2)
discussion.md      — questions to ask your LLM after the workshop
linux/             — Linux probe, scrubber, tests, notes
mac/               — Mac probe, scrubber, tests, notes
windows/           — Windows probe, scrubber, tests, notes
```

Pick your platform's folder when the workshop tells you to. WSL users follow the Linux folder.
