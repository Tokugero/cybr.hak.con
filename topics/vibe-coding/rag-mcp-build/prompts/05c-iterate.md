# Step 05c — Iterate (re-invokable per feature)

## What this step accomplishes (read this yourself)

This prompt is **re-invokable**. You invoke it once per remaining feature. Each invocation runs one full red-green-refactor cycle for the next behaviour the build needs.

You decide how granular to be. A small focused feature (one method, one test) is one invocation. A larger compound feature (e.g. "the ingestion pipeline") might be three invocations: one to fetch HackTricks, one to chunk it, one to ingest it end-to-end. Smaller cycles cost more invocations but give you more checkpoints to verify the assistant is on track.

The token efficiency reason for this shape (versus one big "build everything" prompt) is concrete: each invocation produces verifiable state — green tests, an updated `.overview.md`, an SOP if applicable. If a cycle goes off-rails, you only redo that cycle, not the whole feature set. Cache hits within a 5-minute window across consecutive invocations keep cost reasonable.

When you've built every feature you need, stop invoking this prompt and move to step 06.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant run another TDD red-green-refactor cycle. The participant has invoked you once before for step 05b (the first cycle) and may have invoked you several times for previous step 05c cycles.

Read `AGENTS.md`, the root `.overview.md`, each subsystem's `.overview.md`, and any test files that already have content. The `.overview.md` Exports column tells you what's already implemented. The existing tests tell you what behaviours are already covered.

### Step 1 — propose the next feature with the participant

Look at the deferred behaviour list from step 05b's interview, plus anything that has emerged since. Common candidates for the reference build, in roughly the right order:

1. Chunker — turn a long markdown document into chunks of bounded size with overlap.
2. OllamaEmbedder — real implementation against a real Ollama HTTP endpoint, plus contract test.
3. QdrantStore — real implementation against a Qdrant fake or a real local container, plus contract test.
4. Pipeline — fetch source → chunk → embed → upsert.
5. HackTricks source — git-clone HackTricks, walk markdown files, yield Documents.
6. API search endpoint — wire the library's SearchService into FastAPI.
7. MCP search tool — register the search tool with FastMCP.
8. Ingestion CLI — `python -m <library>.ingest hacktricks`.

Ask the participant: *"Here are the candidates. Which one next? Or something I haven't listed?"* Honour their answer. If their pick depends on a candidate that isn't done yet (e.g. "let's do the API endpoint" before SearchService has a real implementation), point that out — *"this depends on X being done first; do you want to do X first, or stub X for now and revisit?"*

### Step 2 — confirm the behaviour list for this cycle

For the chosen feature, list the concrete behaviours. Keep the list small — 2–4 items max for one invocation. Pick one to test in this cycle; the rest become candidates for the next invocation.

If a feature is too large for one cycle (e.g. "the whole ingestion pipeline"), recommend splitting: *"this is three behaviours. I suggest we do the chunker now, then come back for the embedder integration, then the upsert path. That gives you three checkpoints instead of one mega-cycle."*

### Step 3 — write the failing test (red)

Same discipline as step 05b:
- Test name is the behaviour stated as a sentence.
- One assertion path per test.
- Fixtures from `conftest.py` where possible; mocks for genuinely external things (real HTTP, real Qdrant) where contract tests are appropriate.
- Run the test, confirm it fails for the right reason.

### Step 4 — write the minimum implementation (green)

Smallest code path that makes the failing test pass. Don't pre-empt features that aren't tested yet.

Run the test. If pre-existing tests broke, fix them before continuing — that's a sign of an interface drift you need to handle now, not later.

### Step 5 — refactor

Same as step 05b: rename for intent, factor visible duplication, delete comments that explain what the code already says. Run tests after each refactor step. Skip if nothing's worth refactoring.

### Step 6 — update `.overview.md`

For any file that gained a public symbol, update the relevant subsystem's `.overview.md` Exports column. If a new file was added, add a row to the component table. If a dependency was added, update the Deps column.

This is non-negotiable. The whole point of layered docs is they reflect reality. Letting them drift defeats the loop.

### Step 7 — check the `kb/` for an existing SOP, offer to add one

Before starting the cycle, check `kb/` for any SOP that applies to what you're about to do. If one exists, follow it — that's why it's there.

After the cycle, ask the participant: *"This was non-trivial — would you like me to save it as `kb/sop-<action-name>.md`?"* Most cycles produce no SOP-worthy decisions. The ones that do (e.g. "how to set up a fake Qdrant for contract tests," "how to handle the libstdc++ requirement on NixOS for httpx in nix-shell") are worth keeping.

### Step 8 — stop and report

Stop after one cycle. Tell the participant:

- What feature was built.
- What test now passes (and how to run it).
- What `.overview.md` files were updated.
- What's still on the candidate list for the next invocation.
- Whether to invoke this prompt again, or whether the build is feature-complete and they should move to step 06.

Do not start another cycle in the same invocation.

## When to stop invoking this prompt

The build is feature-complete when:
- The MCP server can answer a search query end-to-end with the library backing it.
- The ingestion CLI can populate Qdrant from a real HackTricks clone.
- All test files have at least one assertion and pass.
- The component tables in each subsystem's `.overview.md` cover every public symbol.

When that's true, move to `prompts/06-end-to-end-and-walkthroughs.md`.

## Outputs you'll have at the end of each invocation

- One additional passing test
- Minimum implementation to support it
- `.overview.md` Exports/Deps columns updated for the touched subsystem
- A clear "what's next" summary
- Optionally: `kb/sop-...md` if the cycle produced one
