# Vibe coding

Topics in this track teach four patterns the speaker has actually shipped real projects with. The patterns aren't about a smarter agent or fancier tooling; they're about moving the project's mental load out of your head and into the project itself, where the agent can read it.

If you saw the talk, this is a refresher. If you didn't, what follows is enough context to start any topic in this track.

## What goes wrong without these patterns

Four failure modes recur across vibe-coding sessions. We refer to them as **F1** through **F4** so they're easy to point at later.

- **F1 — Context exhaustion.** Your agent runs out of context partway through a task. You end up holding the rest of the project in your head, which is the opposite of what vibe coding promised.
- **F2 — Off-rails generation.** Your agent invents files that don't exist, calls functions with the wrong signatures, writes tests that don't catch the actual failure mode. Output looks correct on the surface; reality drifts.
- **F3 — Parallel collisions.** Multiple agents (or you and an agent) end up editing the same files in incompatible ways. Time you spent in parallel becomes time you spend reconciling diffs.
- **F4 — Drift.** Your layered docs go stale. The agent in the next session reads documentation that doesn't match the code, and either follows the docs (producing wrong code) or ignores the docs (defeating the point of having them).

These are the friction shapes. Each pattern in this track addresses a slice of them; no single pattern addresses all four.

## The four patterns

- **Layered context documents.** A small `.abstract.md` (~100 tokens) and a larger `.overview.md` (~2000 tokens) per subsystem, plus the source as the deepest layer. The agent reads top-down and stops as soon as it has enough. Most importantly, the agent **owns** these files — it keeps them current as the code changes. You direct; you don't author.
- **Validation tools and steps.** The feedback loop that lets you trust the agent's output without reading every line. Tests, type checks, lints, build, custom validators — wired so the agent runs them and self-corrects, with permission gates for actions that need human approval (secrets, prod changes, destructive commands).
- **Testing shapes and purpose.** Different test shapes signal different things. Behaviour-first design (confirm interface → confirm behaviours → red → green → refactor) prevents the agent from over-testing the wrong things and under-testing the right ones. Tests live at subsystem boundaries that match the layered docs.
- **Positioning a project to build in parallel.** Decompose the project so multiple workstreams (you and an agent, or two agents) can work without colliding. The orchestrator never edits code directly; it delegates to subagents that own one subsystem each. Domain isolation kills the worst kind of merge conflicts.

The patterns compose: layered docs make validation cheaper because the agent reads less; test shapes make parallel build safer because subsystem boundaries are explicit; the orchestrator pattern only works because the layered docs already let any agent get oriented quickly.

## Topics

| Topic | Patterns exercised | Format |
|-------|-------------------|--------|
| [`rag-mcp-build/`](rag-mcp-build/) | All four | Self-driven workshop |

More topics may be added over time.

## What this track isn't

- A tour of AI machinery. Embeddings, vector stores, retrieval-augmented generation, the Model Context Protocol — these come up only as concrete examples of small useful tools you can build using these patterns. The patterns are the content.
- A specific tool's workflow. The patterns work in any LLM agent tool. The speaker uses [opencode-project-template](https://github.com/Tokugero/opencode-project-template) as their personal source of truth, but the workshop is written tool-agnostically: where it references a dispatch file, it uses `AGENTS.md` because that name reads naturally to every LLM tool you might use.
- A guarantee that AI handles your judgment. The patterns reduce friction; they don't replace deciding what to build, evaluating whether a result is correct, or recognising when the agent is hallucinating in unfamiliar territory.

## Tool agnosticism

Workshops in this track assume you're using *some* LLM agent tool — Claude Code, OpenCode, Cursor, Codex, Aider, or similar — but they don't assume which one. Where a step references a dispatch file the assistant should read first, that file is named `AGENTS.md`:

- **OpenCode** auto-loads `AGENTS.md` at session start.
- **Claude Code** doesn't auto-load `AGENTS.md`, but a one-line `CLAUDE.md` containing `@AGENTS.md` is enough to point it at the same file.
- **Cursor / Codex / others** read whatever you point them at; the workshop's prompts always include a "read `AGENTS.md` first" instruction so explicit context-loading replaces auto-loading.

Where a step references a tool-specific format that has no agnostic equivalent (Claude Code's `.claude/agents/`, OpenCode's `.opencode/agents/`, Cursor's `.cursor/rules/`), the workshop describes the *role pattern* in prose and lets you translate it to your tool's serialization. The patterns are what's being taught; file formats are just delivery.
