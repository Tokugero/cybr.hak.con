# Step 02 — Output and interface

## What this step accomplishes (read this yourself)

You're moving from "what is this project" (step 01) to "what shape does this project have." After this step, you'll have a root `.overview.md` that names the subsystems, the stack, the endpoints, and the dev workflow. The assistant also updates `.abstract.md` to fill in the subsystem table that was a placeholder in step 01.

This step is mostly about decisions, not files. The assistant asks you to commit to: what the tool *produces* and *exposes* (the output contract), how users interact with it (the interface), what subsystems naturally fall out, and what stack you're using. The output is a single ~2000-token L1 file the next session reads to orient quickly.

The assistant continues to own all the layered docs. You direct what changes.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant set up step 02 of the build. The deliverable is the root `.overview.md` and an updated root `.abstract.md`.

Read `.abstract.md` first to remember what project this is. Then proceed.

### Step 1 — confirm what's already decided

Summarise to the participant what `.abstract.md` says. Ask: *"Does the project's purpose still match what we wrote? Or has anything shifted since step 01?"* If they want to revise the abstract, do that first (propose, approve, write — same pattern as step 01). Then continue.

### Step 2 — interview the participant about output and interface

Ask these questions, one at a time, waiting for each answer:

1. **What does the tool produce or expose?** For the reference build: *"a search endpoint that takes a query and returns ranked chunks of relevant HackTricks content, plus an MCP tool wrapping the same."* Honour the participant's actual scope.
2. **How do users interact with it?** Options: HTTP API, MCP tool, CLI, library import, all of the above. For the reference: *"HTTP search endpoint, MCP search tool, and a separate CLI for ingestion."*
3. **What stack are you using?** Don't impose. For the reference: *"Python 3.13, uv for package management, FastAPI + FastMCP for the API, Qdrant for vector storage, Ollama for embeddings (nomic-embed-text, CPU-only), Docker Compose for local dev."*
4. **What subsystems fall out naturally?** Propose, don't impose. For the reference: *"a library subsystem doing ingestion + storage + search; an API subsystem wrapping the library and exposing endpoints."*

If the participant proposes only one subsystem, push back: *"can you split along an interface boundary so two role agents could work in parallel without colliding?"* If they really only have one, the workshop still works but the parallel-build pattern won't be exercised.

### Step 3 — propose updates to `.abstract.md`

Update `.abstract.md`'s subsystem table:

```markdown
| Subsystem | Path | Purpose |
|-----------|------|---------|
| <library> | `<path>/` | <one sentence> |
| <api> | `<path>/` | <one sentence> |
```

Show the updated `.abstract.md`. Approval, then write.

### Step 4 — propose `.overview.md`

Draft `.overview.md` at the project root, targeting roughly 2000 tokens. Use this structure:

```markdown
# .overview.md — <project-name>

L1 context file. For the ultra-concise project map, read `.abstract.md` (L0) first. Subsystems each have their own `.overview.md` for deeper detail.

## What this project is
<one paragraph>

## Repository map
| Subsystem | Path | Type | Purpose |

## Subagent quick-reference
| Task type | First agent to invoke |
| Runtime / metrics / health | `@<project>-sre` |
| <library> changes | `@<project>-<library-role>` |
| <api> changes | `@<project>-<api-role>` |

## Service endpoints
| Service | URL | Notes |

## Stack at a glance
| Layer | Technology |

## Dev workflow
```sh
# Run tests / Start local stack
```

## Storage / persistence
<persistent state: databases, volumes, files, caches>

## Non-negotiables
- Never commit unencrypted secrets
- Never use floating/latest dependency versions
- <project-specific>

## Subsystem context files
| Subsystem | L1 file | L0 file |
```

Some sections will be skeletal — file maps per subsystem aren't known yet (that's step 03), and service endpoints become real once the API is built (step 05). Mark those as *"TBD in step N"* rather than leaving them blank.

### Step 5 — show, approve, write

Show the participant both files (updated `.abstract.md` and new `.overview.md`). Ask: *"Does this match the shape of the project as you understand it? Anything missing, wrong, or ambiguous?"* Iterate until they approve. Write both files.

### Step 6 — stop

Do not proceed to step 03. Wait for the participant to invoke `prompts/03-skeleton-docs-and-gates.md`.

## Outputs you'll have at the end of this step

- `.abstract.md` updated with the real subsystem table (no placeholder row)
- `.overview.md` at the project root, roughly 2000 tokens, owned by your assistant
- Decisions captured: subsystems, stack, interface shape, dev workflow — all visible in one file for any future session
