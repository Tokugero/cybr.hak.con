# Step 03 — Skeleton, layered docs, and permission gates

## What this step accomplishes (read this yourself)

This is the heaviest step in the workshop. After it, you have the project's full agent infrastructure: an `AGENTS.md` dispatch file describing three role patterns (orchestrator, SRE, and one role agent per subsystem), a `protocols.md` capturing your permission gates and secrets handling, an empty `kb/` knowledge base, per-subsystem `.abstract.md` and `.overview.md` stubs, and a few operational stubs (`docs/sre-todos.md`, `docs/session-log.md`).

No code is written here. This step is the project's *skeleton* — the structure that subsequent steps fill in. The assistant proposes the entire scaffold up front, you review and redirect, then it writes everything in one batch.

Two important things land here that don't reappear:

1. **Permission gates.** `protocols.md` lists actions the assistant must always pause for: writing secrets, applying changes to production, destructive commands, multi-node actions, force-pushing or rewriting git history. From step 04 onward, the assistant follows these gates without re-asking.
2. **Tool-agnostic dispatch.** The dispatch file is `AGENTS.md`. A one-line `CLAUDE.md` (`@AGENTS.md`) makes Claude Code auto-load it; OpenCode auto-loads `AGENTS.md` natively; Cursor / Codex / others read it when prompts reference it. The role descriptions in `AGENTS.md` are *patterns*, not tool-specific subagent files — your tool may or may not have a way to materialise them as actual subagents.

If your tool supports subagents (Claude Code's `.claude/agents/`, OpenCode's `.opencode/agents/`), the assistant will offer to translate the role descriptions in `AGENTS.md` into your tool's serialization. If it doesn't, the role patterns work as prose your assistant references each session.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant set up step 03 of the build. The deliverable is the project's agent infrastructure and per-subsystem layered doc stubs. No source code yet.

Read `.abstract.md` and `.overview.md` first. They name the subsystems, stack, and project shape.

### Step 1 — confirm what your tool supports

Ask the participant which LLM agent tool they're using (Claude Code, OpenCode, Cursor, Codex, Aider, or other). The answer affects two things:

- **Dispatch file auto-loading.** OpenCode auto-loads `AGENTS.md`. Claude Code auto-loads `CLAUDE.md` — we'll create a one-line `CLAUDE.md` containing `@AGENTS.md` so it picks up the same content. Other tools read what you point them at; the workshop's prompts always include explicit "read AGENTS.md first" instructions.
- **Subagent materialisation.** Claude Code uses `.claude/agents/*.md`. OpenCode uses `.opencode/agents/*.md`. Cursor uses `.cursor/rules/*.mdc`. Codex has no subagent convention; the role patterns stay as prose in AGENTS.md. Ask the participant whether they want you to offer tool-specific subagent files at the end of this step (default: no — keep it tool-agnostic; the patterns in AGENTS.md are enough).

### Step 2 — propose the full scaffold up front

Before writing anything, list every file you plan to create with a one-sentence purpose for each. Use this structure (substitute `<library>` and `<api>` with the actual subsystem names from `.abstract.md`):

| File | Purpose |
|------|---------|
| `AGENTS.md` | Dispatch file: project structure, three role patterns (orchestrator + SRE + one per subsystem), delegation rules, permission gates, session-start checks |
| `CLAUDE.md` | One-line `@AGENTS.md` so Claude Code auto-loads the dispatch file |
| `protocols.md` | Secrets handling (read from disk, never inline), code style, permission gates, dev shell setup |
| `kb/README.md` | Knowledge base index, empty until SOPs are added |
| `docs/sre-todos.md` | Stub for SRE-flagged non-urgent findings; appended to as the project evolves |
| `docs/session-log.md` | Historical session notes, *not* loaded into prompt context — reference for humans only |
| `<library>/.abstract.md` | L0 subsystem orientation stub (~100 tokens; populated as code lands) |
| `<library>/.overview.md` | L1 subsystem context stub (~2000 tokens; populated as code lands) |
| `<api>/.abstract.md` | Same shape, for the API subsystem |
| `<api>/.overview.md` | Same shape, for the API subsystem |
| `.envrc` | direnv config (`use flake` if Nix; otherwise activates `uv` virtualenv) — optional, ask the participant |
| `.gitignore` | Append: `docs/.tmp/`, `in-progress.md`, `.envrc.local`, `.template-local`, `.env`, `secrets/` |

Show this list to the participant. Ask: *"Anything you'd remove, add, or rename before I draft contents?"*

### Step 3 — draft contents

Once the file list is approved, draft contents for each. The longer ones are below; the stubs are obvious.

#### `AGENTS.md` content shape

```markdown
# AGENTS.md — <project-name>

## Purpose
Dispatch file for <project-name>. Describes the project's structure, the three role patterns, delegation rules, permission gates, and session-start checks. Read this first in every session.

> Protocols are in `protocols.md`. Session history is in `docs/session-log.md` and is *not* loaded into prompt context.

## Repository structure
<tree showing AGENTS.md, .abstract.md, .overview.md, protocols.md, kb/, docs/, <library>/, <api>/>

## Role patterns

### Orchestrator
The agent the human talks to directly. Reads this file, identifies which role pattern owns the task, and delegates. Never edits files or runs git commands. Does the session-start checks below before any task.

### SRE — cross-system observer
Read-only. Reads root `.abstract.md` and `.overview.md`, plus each subsystem's. Queries live state (logs, metrics, health endpoints). Never reads source files. Never modifies anything. Recommends fixes; the orchestrator routes them to a role agent.

### <library role>
Owns `<library>/` exclusively. Reads `<library>/.abstract.md` then `<library>/.overview.md` before acting. Keeps both files current as code changes. Asks before any first-of-a-kind action class. Routes runtime issues to the SRE pattern.

### <api role>
Owns `<api>/` exclusively. Same protocol as <library role>.

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
```

#### `protocols.md` content shape

```markdown
# protocols.md — <project-name>

Operational protocols for any agent working in this repository.

## Secrets
- **Never inline a secret value in a shell command.** Read from disk at runtime.
- `.env` for operational config (passwords, DSNs, API keys). Gitignored.
- `secrets/<name>` for standalone credential files. Gitignored.
- Missing secret: if safe to generate (e.g. a random token), generate, write, tell the human. If it must come from the human, stop and ask.

## Code style
- <participant fills in: indentation, naming conventions, dependency policy>
- Specific dependency versions — never floating/latest.

## Permission gates — always ask before
1. Writing or modifying any secret or credential file.
2. Applying changes to a production system.
3. Running destructive commands (delete, drop, reset, purge).
4. Any action affecting more than one node/instance simultaneously.
5. Deleting git history or running `git push --force`.

Each gate requires a fresh ask, even if a similar action was approved earlier in the session.

## Dev shell
<participant fills in: direnv + Nix, Python virtualenv via uv, etc.>
```

#### `kb/README.md` content shape

```markdown
# Knowledge base — <project-name>

Standard operating procedures (SOPs) and runbooks generated during development. Check here before starting any non-trivial task.

| File | What it covers | Last updated |
|------|---------------|-------------|
| *(empty — add SOPs as they are created)* | | |

## Adding an SOP
After completing a non-trivial action, the orchestrator may ask: *"Save this as an SOP?"* If yes, create `kb/sop-<action-name>.md` with: When to use / Prerequisites / Inputs required / Steps / Expected output / Known failure modes. Add a row to this table.
```

#### Subsystem stubs (one per subsystem)

`<subsystem>/.abstract.md` (~100 tokens):
```markdown
# .abstract.md — <subsystem>

L0 subsystem map. For full detail, read `.overview.md` (L1).

| File | Purpose |
|------|---------|
| *(populated as code lands)* | |
```

`<subsystem>/.overview.md` (~2000 tokens):
```markdown
# .overview.md — <subsystem>

L1 subsystem context. Components, exports, dependencies, dev workflow.

## What this subsystem does
<one paragraph>

## Component table
| Path | Type | Purpose | Exports | Deps |
|------|------|---------|---------|------|
| *(populated in step 05 as files land)* | | | | |

## Dependencies on other subsystems
<which subsystems this one depends on, if any>

## Dev workflow
```sh
# Run tests / lint / typecheck
# <commands>
```

## Test commands
<filled in during step 04>
```

### Step 4 — show, approve, write

Show the participant the contents of every non-stub file (AGENTS.md, protocols.md, kb/README.md, .gitignore additions, .envrc). Ask: *"Anything to change before I write these to disk?"* Iterate. Write everything in one batch.

For the stub files (subsystem `.abstract.md` and `.overview.md`, `docs/sre-todos.md`, `docs/session-log.md`), write them without per-file approval — they're obvious skeletons.

### Step 5 — offer tool-specific subagents (optional)

If the participant said yes in step 1 to materialising subagents in their tool's format, offer to create `.claude/agents/*.md` (Claude Code), `.opencode/agents/*.md` (OpenCode), or `.cursor/rules/*.mdc` (Cursor) files derived from the role descriptions in `AGENTS.md`. Otherwise skip this step — the role descriptions in `AGENTS.md` are sufficient.

### Step 6 — stop

Do not proceed to step 04. Wait for the participant to invoke `prompts/04-tests-and-test-structure.md`.

## Outputs you'll have at the end of this step

- `AGENTS.md` describing the project's three role patterns
- `CLAUDE.md` with `@AGENTS.md` for Claude Code users (skip if not on Claude Code)
- `protocols.md` with secrets handling, code style, the five permission gates, dev shell setup
- `kb/README.md` (empty index), `docs/sre-todos.md` (empty stub), `docs/session-log.md` (empty stub)
- Per-subsystem `.abstract.md` and `.overview.md` stubs
- `.gitignore` augmented for the operational files
- Optionally: tool-specific subagent files derived from the role descriptions
