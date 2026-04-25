# cybr.hak.con

Companion materials for talks and workshops on sandboxing AI coding agents (Claude Code, opencode, Cursor agents, and similar) on Mac, Windows, and Linux.

## What this is

A self-contained set of workshops and reference notes you can clone and work through on your own. Each topic stands alone; pick one based on what you want to learn. Most topics are meant to be drop-in/drop-out — start at any time, leave whenever, come back to where you were.

## Who this is for

You probably came from the talk. If you didn't, that's fine too — every topic's `README.md` and `workshop.md` explains enough to start cold.

## What you need

Tools vary by topic. Each topic's README lists what it expects. The common floor:

- A shell: `bash` or `zsh` on Mac/Linux/WSL, or PowerShell 7+ on Windows.
- `git`, to clone this repo.
- An LLM client of your choice (Claude, ChatGPT, a local model, anything that can read markdown).

Some topics need additional free, popular tools (`direnv`, `docker`, `qemu/kvm`, `bats`, `Pester`). Each topic lists its own.

Nothing in this repo costs money or requires a paid account.

## Layout

```
topics/
  sandboxing/        — isolating AI coding agents
    README.md        — threat model, tier vocabulary, topic index
    cred-scrub/      — keep credentials out of your agent's reach (workshop)
    ...              — more topics as they're added
```

More tracks may appear over time. Look for a `topics/<track>/README.md` for the framing of each.

## How to use this with an LLM

Most LLM clients pick up `CLAUDE.md` automatically. If yours doesn't, point it at `CLAUDE.md` manually — it's a short orientation file that tells the LLM how the repo is laid out and what kinds of questions you're likely to ask.

Each topic also has a `discussion.md` with prompts written to be handed directly to your LLM after you've worked through the material. Use them to go deeper.

## How to use this without an LLM

Every topic is plain markdown. Read the `README.md`, follow the `workshop.md`, look at `discussion.md` if you want to keep going. The LLM is a tutor, not a requirement.
