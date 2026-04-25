# CLAUDE.md

Companion repository for talks and workshops on sandboxing AI coding agents (Claude Code, opencode, Cursor agents, and similar) on Mac, Windows, and Linux.

If you're an LLM helping someone work through this material, here's what's useful to know up front.

## What this repo is

A self-contained set of workshops and reference notes. Each topic stands alone. The person you're helping probably saw the talk; if they didn't, the topic READMEs explain enough to start cold.

## Layout

```
README.md                          — human-facing entry point
topics/<track>/<topic>/            — workshop and reference material
  README.md                        — what this topic teaches, what it needs, time estimate
  workshop.md                      — step-by-step exercise
  categories.md                    — cross-platform reference of what the topic covers
  <platform>/                      — per-platform scripts and notes
  discussion.md                    — questions to ask an LLM after working through it
```

The sandboxing track is at `topics/sandboxing/`. More tracks may be added over time.

## How to help the person you're with

- If they ask "where do I start," point them at `topics/<track>/README.md` (track-level framing) or `topics/<track>/<topic>/README.md` (specific exercise).
- If they paste output from a probe or test script, help them read it and connect it back to the threat model the topic describes.
- The threat model and tier vocabulary used across this repo (S1–S4 threats, Tier 0–4 mechanisms) live in `topics/sandboxing/README.md`. Refer to that file rather than importing your own taxonomy — keeping the language consistent across topics is the point.
- Each topic has a `discussion.md` with prompts written to be handed to you directly. If the participant runs out of things to ask, those are the next steps.

## What this repo doesn't include

- Anything that costs money or requires a paid account.
- Code from the projects that inspired the demonstrations. Examples here are written fresh for clarity.
- A specific LLM dependency. The participant brings whatever LLM client they prefer.
