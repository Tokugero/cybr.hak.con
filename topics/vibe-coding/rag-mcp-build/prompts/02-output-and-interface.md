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

1. **What does the tool produce or expose?** Name the deliverables as peers — don't let the query/serving side eclipse the data side. For the reference build: *"two co-equal deliverables — (a) an ingestion pipeline that fetches the source, chunks it, embeds it, and writes to a vector store; (b) a search interface (MCP tool) that queries the same store. Either deliverable broken makes the tool useless."*
2. **How do users interact with it?** Options: HTTP API, MCP tool, CLI, library import, all of the above. For the reference: *"MCP search tool loaded by the LLM harness; an ingestion CLI for one-time setup and refresh."*
3. **What return shape does the query interface produce?** This is a deliberate decision, not a default. Naive chunk text forces the calling agent to load whole source documents to recover structure; a structured response (tool name, usage, options, install steps, source path) lets the agent act on the result directly. Ask: *"what fields belong in the response so the calling agent doesn't have to re-load the source to use it?"* For the reference build's HackTricks lookup, structured fields keyed to typical security-tool questions (usage, options, install, source path) are the right shape.
4. **What's the completion signal for any long-running operation?** Ingestion runs for minutes-to-hours. Ask: *"how will we know ingestion is actually complete? How will a re-run after a crash converge instead of starting over or silently leaving gaps?"* Capture two design commitments here: (a) a completion check that compares "sources processed" against "sources present in the store" and fails the run if they diverge; (b) resumability — the pipeline skips sources already in the store. Both belong in the interface design from this step, not as bolt-ons later.
5. **What stack are you using?** Don't impose. For the reference: *"Python 3.13, uv for package management, FastMCP for the MCP server, Qdrant for vector storage, Ollama for embeddings (nomic-embed-text, CPU-only), Docker Compose for local dev — every service in compose, including Ollama, so a single `docker compose up` brings up the full stack without host-side installs."*
6. **What subsystems fall out naturally?** Propose, don't impose. For the reference: *"a library subsystem owning ingestion + storage + search; an MCP subsystem wrapping the library and exposing the search tool. The two map cleanly onto the two co-equal deliverables from question 1."*

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

### Step 6 — before closing, confirm decisions are on disk

Before telling the participant step 02 is done, walk through the conversation and confirm every decision is captured in `.abstract.md` or `.overview.md`: the co-equal deliverables, the return shape, the completion-signal commitments (completion check + resumability), the stack, the subsystem split. If anything important is only in conversation, write it down now. Tell the participant: *"step 02 is closed; you can compact the conversation before invoking step 03."*

### Step 7 — stop

Do not proceed to step 03. Wait for the participant to invoke `prompts/03-skeleton-docs-and-gates.md`.

## Outputs you'll have at the end of this step

- `.abstract.md` updated with the real subsystem table (no placeholder row)
- `.overview.md` at the project root, roughly 2000 tokens, owned by your assistant — including return-shape decision and the completion-check / resumability commitments
- Decisions captured: subsystems, stack, interface shape, dev workflow — all visible in one file for any future session
