# Composition

A synthesis workshop. Brings the four other sandboxing topics together and answers the question: *which layers do I actually compose for which threat model?*

Tier 0 (cred-scrub + direnv-perimeter) is always the base. Above it, you pick one of:
- **Tier 1 — process-level (bwrap)** — light, fast, Linux-only.
- **Tier 2 — container (Docker)** — heavier setup, more portable, more flags to verify.
- **Tier 2 + network-egress** — when egress control matters, not just filesystem.

This topic doesn't introduce new mechanisms. It teaches you to *read* a setup and tell what threats it addresses, and to *write* one for a given scenario.

## What you'll learn

- Why Tier 0 sits at the base of every real composition.
- Why you pick *one* Tier 1+ layer, not all of them — and how to choose.
- Where network-egress fits as an orthogonal axis (separate from filesystem).
- How to read a `docker run` invocation, an `.envrc`, or a `bwrap` command and tell what threats survive it.
- How to write a composed setup for a specific scenario (Scenarios A–H from the talk).

## Threats addressed

Composition pushes coverage across **all four** threat scenarios — but only when the right layers are stacked. The matrix at the end of `workshop.md` makes this concrete.

For the threat model, see `../README.md`.

## Prerequisites

You should have already worked through (or at least skimmed):

- [`cred-scrub/`](../cred-scrub/) — Tier 0 hygiene
- [`direnv-perimeter/`](../direnv-perimeter/) — Tier 0 boundary + scoped injection
- [`process-isolation/`](../process-isolation/) — Tier 1 (bwrap)
- [`container-isolation/`](../container-isolation/) — Tier 2 filesystem
- [`network-egress/`](../network-egress/) — Tier 2 network axis

This workshop assumes the vocabulary, the probes, and the patterns from those topics.

## What you need

- All the dependencies of the topics above. See `../../REQUIREMENTS.md`.
- For the bwrap composition: `bubblewrap` (Linux only).
- For the Docker compositions: `docker` and `docker compose` v2.

## Time

- Surface pass: ~25 minutes (read the workshop, run the three example runners, watch what each layer adds).
- Including the matrix exercise and discussion: ~75.

## Layout

```
README.md                    — this file
workshop.md                  — the exercise: three example compositions + the threat-coverage matrix
discussion.md                — questions to ask your LLM
PORTING.md                   — handoff doc for Mac and Windows
linux/
  compose-bwrap.sh           — Tier 0 + Tier 1 (bubblewrap) example
  compose-docker.sh          — Tier 0 + Tier 2 (hardened Docker) example
  compose-docker-egress.sh   — Tier 0 + Tier 2 + network-egress sidecar example
  notes.md                   — Linux-specific composition notes
  tests/run.sh               — verifies each composition produces the expected probe output
```

WSL users follow the Linux folder. Mac and Windows aren't built — see `PORTING.md`.
