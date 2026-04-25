# direnv as a perimeter

A workshop on direnv treated as a *boundary mechanism*, not just a tool. Anything spawned inside a directory inherits the rules its `.envrc` sets up — your shell, your scripts, your LLM client, the LLM's subagents. That's the perimeter.

## What you'll learn

- What direnv actually does — the trust gate, the shell hook, on-cd-in and on-cd-out behavior.
- The two halves of the Tier 0 perimeter pattern: **scrubbing** broad credentials *and* **injecting** narrow scoped ones.
- How nested `.envrc` files compose, and what survives the unload when you `cd` out.
- How to verify whether the perimeter actually applied to a running LLM session.
- Patterns for scoped credential injection: `.envrc.local`, `aws-vault`, Kubernetes scoped contexts, short-lived secrets from a manager.

## Threats addressed

- **S1 (credential exfiltration via poisoned context)** — combined removal + narrowly-scoped injection limits what's reachable when a poisoned input reads your credentials.
- **S3 (scope creep on benign tasks)** — per-directory credentials reduce what an agent's *summarize my project* task can accidentally touch.

For the full threat model and tier vocabulary, see `../README.md`.

## Relationship to cred-scrub

This workshop **builds on** [`../cred-scrub/`](../cred-scrub/). Cred-scrub focuses on credential *removal*: what an agent should not find in the environment. This workshop focuses on the perimeter idea — how the directory itself becomes a boundary — and the other half of Tier 0: scoped *injection*. If you haven't done cred-scrub yet, skim its `workshop.md` first; you'll want the vocabulary.

## What you need

- A shell: `bash` or `zsh` on Mac/Linux/WSL, or PowerShell 7+ on Windows.
- `direnv`. [Installation](https://direnv.net/docs/installation.html). Free, in every major package manager.

The test harness is a plain shell script — no extra dependency.

## Time

- Surface pass: ~20 minutes.
- Including the patterns reference and discussion prompts: up to ~75.

The workshop is drop-in/drop-out. Stop wherever; come back later.

## Layout

```
README.md          — this file
workshop.md        — the exercise
patterns.md        — scoped credential injection patterns (reference, not runnable)
discussion.md      — questions to ask your LLM after the workshop
PORTING.md         — handoff doc for adding Mac and Windows
linux/             — Linux fingerprint script, sample .envrc files, notes, tests
```

Pick your platform's folder when the workshop tells you to. **Mac and Windows aren't built yet** — see `PORTING.md` for the porting checklist. WSL users follow the Linux folder.
