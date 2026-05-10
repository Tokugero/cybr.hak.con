# AGENTS.md — rag-mcp-build

## Purpose
Dispatch file for rag-mcp-build. Describes the project's structure, the three role patterns, delegation rules, permission gates, and session-start checks. Read this first in every session.

> Protocols are in `protocols.md`. Session history is in `docs/session-log.md` and is *not* loaded into prompt context.

## Repository structure

```
rag-mcp-build/
├── AGENTS.md
├── CLAUDE.md
├── protocols.md
├── .abstract.md
├── .overview.md
├── kb/
│   └── README.md
├── docs/
│   ├── sre-todos.md
│   └── session-log.md
├── lib/
│   ├── .abstract.md
│   └── .overview.md
└── mcp/
    ├── .abstract.md
    └── .overview.md
```

## Role patterns

### Orchestrator
The agent the human talks to directly. Reads this file, identifies which role pattern owns the task, and delegates. Does the session-start checks below before any task.

### SRE — cross-system observer
Read-only. Reads root `.abstract.md` and `.overview.md`, plus each subsystem's. Queries live state (logs, metrics, health endpoints). Never reads source files. Never modifies anything. Recommends fixes; the orchestrator routes them to a role agent.

### Library role (`@rag-mcp-library`)
Owns `lib/` exclusively. Reads `lib/.abstract.md` then `lib/.overview.md` before acting. Keeps both files current as code changes. Asks before any first-of-a-kind action class. Routes runtime issues to the SRE pattern.

**Test commands:**
- `uv run pytest lib/`
- `uv run pytest lib/ --cov`

### MCP role (`@rag-mcp-mcp`)
Owns `mcp/` exclusively. Same protocol as the library role. Reads `mcp/.abstract.md` then `mcp/.overview.md` before acting.

**Test commands:**
- `uv run pytest mcp/`
- `uv run pytest mcp/ --cov`

## Delegation rules
1. Read this file. Identify which role pattern fits the task.
2. Announce the delegation in one line: *"Delegating to <role>: <one-line reason>."* Then proceed.
3. The owning role pattern reads its own `.abstract.md` then `.overview.md` first; reads source files only as needed.
4. After completion, update the relevant `.overview.md` if anything in the component table changed.

## Session-start checks
Before any task, do these three checks:

1. **Interrupted work:** look for `in-progress.md` files. If any, surface them and ask whether to resume, discard, or continue with new work.
2. **SRE TODOs:** look for entries in `docs/sre-todos.md` with `Status: open`. If any, summarise before proceeding.
3. **Layered docs sync:** if any source file is newer than its subsystem's `.overview.md`, the docs may have drifted. Surface the drift and offer to refresh before proceeding.

## Permission gates
See `protocols.md` for the full list. The five gates require a fresh ask, even if a similar action was approved earlier in the session.
