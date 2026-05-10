# Step 06 — End-to-end and walkthroughs

## What this step accomplishes (read this yourself)

The build is feature-complete after step 05c. This step does three things to *prove* the parts compose:

1. **Cross-system review by the SRE pattern.** The SRE role from `AGENTS.md` reads every subsystem's `.abstract.md` and `.overview.md` (never source) and reports on the system as a whole. Are the subsystem boundaries clean? Are there gaps where two subsystems disagree about an interface? This is the agent that doesn't write code; its value is the cross-cutting visibility a single role agent doesn't have.
2. **End-to-end harness with real services.** Up to now, the library was tested with fakes and the API was tested with mocks. Step 06 brings up Qdrant via Docker Compose, runs a real ingestion against a small fixture, runs a real search through the API, and validates the result. This catches the bugs unit tests can't.
3. **Walkthrough doc for humans.** A short `docs/walkthrough.md` for anyone (you in three months, a teammate, a security reviewer) who wants to confirm the build works without re-reading every prompt. It covers: bring up the stack, ingest a small fixture, run a canonical query, check the result.

The MCP wiring step (connecting the running server to your AI tool) is mentioned at the end of this prompt but happens after the workshop closes. It's tool-specific and doesn't need to land in the workshop's filesystem — see the workshop README's "Tool-specific final step" section.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant run the final step of the build. The deliverable is: an SRE review, a working docker-compose stack, a passing end-to-end harness, a walkthrough document.

Read `AGENTS.md`, the root `.overview.md`, every subsystem's `.overview.md`, and any open SRE TODOs in `docs/sre-todos.md`. Do *not* read source files at this stage — the SRE pattern explicitly avoids them.

### Step 1 — SRE cross-system review

Acting as the SRE pattern from `AGENTS.md`:

1. Read root `.abstract.md` to remember the project shape.
2. Read root `.overview.md` for the full repository map and stack.
3. Read each subsystem's `.abstract.md` and `.overview.md`.
4. Look for: subsystem boundaries that are unclear or duplicated; interfaces where two subsystems disagree (e.g. the API expects a SearchResult shape that doesn't match the library's); missing pieces (e.g. an ingest CLI listed in the API's `.overview.md` but not in the library's component table); endpoints listed in the root `.overview.md` that no subsystem actually provides.

Produce a short report (in the conversation, not as a file unless the participant asks). Format:

```markdown
## SRE cross-system review

### Coherence
- <pass / issue>: <one-sentence finding>

### Gaps
- <subsystem>: <what's missing or contradicted>

### Recommendations
1. <action> — owned by <role>
2. ...
```

If there are gaps, route them to the appropriate role agent before continuing. The SRE pattern doesn't fix things; it surfaces them.

If the participant's tool supports subagents and a real SRE agent was set up in step 03, run this step through that agent. Otherwise, "act as" the SRE pattern by following the protocol above.

### Step 2 — propose docker-compose

Two constraints land here, both non-negotiable:

1. **Everything in compose, including Ollama.** No host-side `ollama pull`. Backing services live in the compose network so a single `docker compose up` brings up the full stack and `docker compose down -v` removes everything cleanly. The workshop is about sandboxing agent tooling — leaving an LLM endpoint on the host contradicts the meta-theme even before the reproducibility argument.
2. **Only the entry-point service publishes a port.** Backing services (Qdrant, Ollama, anything else) are reachable only on the internal compose network, by service name. If a service appears unreachable from inside the entry-point container, the fix is service-name DNS or an env var pointing at `http://<service>:<port>`, **not** adding a `ports:` entry. Publishing the port to the host leaks the service and undermines the sandboxing the workshop is teaching.

Before writing image pins, perform an explicit lookup of current stable for each image (per `protocols.md`'s external-dependencies rule). For paired client/server stacks (Qdrant Python client ↔ Qdrant server, Ollama Python client ↔ Ollama server), pick a server version compatible with the client version already pinned in `pyproject.toml`. Show the participant the looked-up versions before pinning.

Compose skeleton (substitute looked-up versions and adapt service names to the project's subsystems):

```yaml
services:
  qdrant:
    image: qdrant/qdrant:<looked-up-stable>    # as of <date>, current stable; matches qdrant-client X.Y in lib/pyproject.toml
    volumes:
      - qdrant-data:/qdrant/storage
    # no ports: section — internal-only

  ollama:
    image: ollama/ollama:<looked-up-stable>    # as of <date>, current stable
    volumes:
      - ollama-data:/root/.ollama
    # no ports: section — internal-only

  ingest:
    build: ./<library>
    profiles: [ingest]
    depends_on: [qdrant, ollama]
    environment:
      QDRANT_URL: http://qdrant:6333
      OLLAMA_URL: http://ollama:11434
      # ... other env (HACKTRICKS_REPO_URL, etc.)
    volumes:
      - source-data:/data

volumes:
  qdrant-data:
  ollama-data:
  source-data:
```

The MCP service (when it runs in compose) is the only thing that should ever publish a port to the host — and it only needs to do so if the participant's LLM tool connects over HTTP. For a stdio-loaded MCP the harness invokes directly, even the MCP service stays internal.

Show the participant. Confirm the looked-up versions, then ask: *"Anything to change before I write these?"* Iterate. Write.

Update `.overview.md`'s Deps column for any subsystem touched by these pins, with a one-line dated note per `protocols.md`.

### Step 3 — write the end-to-end harness

The harness must exercise the real ingestion path against the real source. Unit tests with mocks do not count for this gate — that's what step 05 was for. The point of the end-to-end is catching the bugs only the real stack reveals (client/server API drift, embedding-dim mismatches, transport failures, paragraph shapes that crash the chunker).

Create `<library>/tests/test_e2e.py` (or `tests/e2e/` at the project root — discuss with participant):

```python
# Skipped by default; opt-in via env var because it requires real services.
import os
import pytest

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_E2E") != "1",
    reason="set RUN_E2E=1 to run end-to-end tests"
)

@pytest.fixture(scope="module")
def real_stack():
    # Bring up qdrant + ollama via docker-compose
    # Yield handles to the running services
    ...

def test_real_ingest_then_search(real_stack):
    # Use real OllamaEmbedder and QdrantStore against the live services.
    # Ingest a small but real subset of the actual source (e.g. 10 files cloned
    # from the real source repo — NOT hand-seeded fixtures).
    # After ingest, verify the completeness check passes: every source the
    # iterator yielded has at least one point in the store.
    # Search for a known keyword that exists in the ingested subset.
    # Assert the seeded doc comes back top-1.
    ...

def test_resumable_ingest(real_stack):
    # Run ingest twice against the same source.
    # Second run skips every source — the pipeline must be idempotent.
    ...
```

The test is opt-in (`RUN_E2E=1`) because it needs real Qdrant and real Ollama running. Discuss whether the harness should manage stack lifecycle (`docker compose up -d` in setup, `down` in teardown) or assume it's running.

Show, approve, write.

### Step 4 — run the stack and the harness

```sh
docker compose up -d qdrant ollama
RUN_E2E=1 cd <library>/ && uv run pytest tests/test_e2e.py -v
```

If the harness fails, debug. Common failure modes:
- Service not reachable — check the service container is up and the entry-point service is on the same compose network. Do NOT "fix" this by adding `ports:` to the backing service; the fix is service-name DNS (`http://qdrant:6333`, `http://ollama:11434`).
- Client/server API drift — the agent wrote against an older API of the installed client. Re-check the installed library's surface (per `protocols.md`'s live-library-surface rule).
- Embedding dimension mismatch — `nomic-embed-text` produces 768-dim vectors; the Qdrant collection must be created with `size=768`.
- Chunker crash on oversized paragraph — the cascade decision in 05a was supposed to handle this; if it crashes anyway, the test corpus didn't include an adversarial fixture. Add one.

### Step 5 — full ingestion + populated-state check

The workshop does not declare done on a healthy unit test suite. The participant's tool is the MCP search — and a search that returns nothing is a broken build, even with green unit tests. Before moving on:

1. Run real ingestion against the real source — at minimum a bounded subset large enough to make a search meaningful. For the reference build, the participant either runs the full HackTricks ingestion (long; minutes-to-hours on CPU embeddings) or a deliberate subset of the real repo (not hand-seeded fixtures).
2. After ingest, run the completeness check: every source the iterator yielded has at least one point in the store. If any are missing, ingestion crashed silently mid-run — fix and re-run before continuing.
3. Run a canonical query against the populated store. For the reference build, examples like *"certipy"*, *"adcs"*, or *"SQL injection bypass"* should return relevant chunks. If they don't, the build is not done.

For long-running ingestion, give the participant a denominator they can use to gauge progress. For the reference build, full HackTricks ingestion is approximately 6,000 points in Qdrant (as of when the workshop was last validated — treat as a ballpark, not a contract; HackTricks grows). The participant can `curl http://localhost:6333/collections/hacktricks` to see live count.

### Step 6 — write `docs/walkthrough.md`

Short doc for humans. Format:

```markdown
# Walkthrough: confirming the build works

## Prerequisites
- Docker with Compose v2
- Python 3.13 + uv
- An LLM agent tool (Claude Code, OpenCode, Cursor, Codex, Aider, or similar)

That's the full list. No host-side service installs — everything runs in compose.

## Bring up the stack
```sh
docker compose up -d qdrant ollama
docker compose exec ollama ollama pull nomic-embed-text    # one-time, persists in the ollama-data volume
```

## Run the end-to-end harness against real ingestion
```sh
cd <library>/ && RUN_E2E=1 uv run pytest tests/test_e2e.py -v
```

This pulls a bounded subset of the real source, ingests it through the real Ollama + Qdrant stack, verifies completeness, and runs a canonical search. If it passes, the build is correct in shape.

## Ingest the full corpus (one-time setup)
```sh
docker compose --profile ingest run --rm ingest
```

This clones the source, chunks all markdown files, embeds via Ollama, and writes to the `hacktricks` Qdrant collection. On CPU with `nomic-embed-text` this takes several hours for the full corpus (reference build: ~6,000 points; track progress with `curl http://localhost:6333/collections/hacktricks | jq .result.points_count`). The pipeline is resumable — if it's interrupted, re-running picks up where it stopped.

## Tear down
```sh
docker compose down
# or, to wipe Qdrant + Ollama data too:
docker compose down -v
```

## What this proves
The full pipeline (source → chunker → embedder → store → search via MCP) is connected end-to-end with real services. If the end-to-end harness passes and a canonical query against the full corpus returns sensible results, the build is correct in shape. If you change a subsystem, re-run the harness as a smoke check.
```

Show, approve, write.

### Step 7 — final updates to root `.overview.md`

- Service endpoints section: list internal-only services explicitly (Qdrant at `http://qdrant:6333` on the compose network, Ollama at `http://ollama:11434` on the compose network, MCP via stdio). If anything publishes a host port, justify in the same row.
- Dev workflow section: add the docker-compose and walkthrough commands; remove any reference to host-side Ollama installs.
- Storage section: note Qdrant data lives in the `qdrant-data` volume; Ollama models in `ollama-data`.

Update `.abstract.md` if anything in the subsystem table shifted.

### Step 8 — final completion gate

The workshop is **not** done until all of the following are true:

- The end-to-end harness from step 3 passes against the real stack.
- A real ingestion has been run (subset is fine) and the completeness check passes.
- A canonical query against the populated store returns sensible results.
- The most recent test runs (per-subsystem) are green — not "passed earlier in the session." If anything has changed since the last run, re-run.
- No backing service in `docker-compose.yml` publishes a port to the host.

If any of these fails, fix it before reporting workshop-complete. A green test suite with an empty database, or a passing harness with a Qdrant exposed to the host network, is not done.

### Step 9 — note the tool-specific final step

Tell the participant explicitly:

> The build is workshop-complete. Wiring the running MCP server into your AI tool is a tool-specific step that lives in the workshop README's "Tool-specific final step" section. It's not in this prompt because the right action depends on which tool you're using:
>
> - Claude Code: add the server to `.mcp.json`
> - OpenCode: add to `opencode.json` under `mcpServers`
> - Cursor / Codex / other: use whatever your tool's MCP support looks like, or hit the HTTP endpoint directly
>
> Once wired, your assistant can call the search tool to look up source techniques without copy-pasting anything from the source.

### Step 10 — stop

Congratulate the participant. Suggest two things they might do next (both optional):

1. Run the full ingestion (the harness uses a bounded subset; the full run ingests everything — hours on CPU embeddings, reference build was ~6,000 points). Then use the MCP tool against it for real work.
2. Apply the same patterns to a project they're already working on — the talk's closing first step is `.abstract.md` for an existing project.

## Outputs you'll have at the end of this step

- An SRE cross-system review (in conversation; or persisted to `docs/.tmp/sre-review-<date>.md` if the participant asks)
- `docker-compose.yml` with explicit-lookup-pinned image versions, all backing services internal-only, Ollama in compose (no host install)
- `<library>/tests/test_e2e.py` (or equivalent), opt-in via `RUN_E2E=1`, exercising real ingestion and resumability
- `docs/walkthrough.md` for human verification
- Root `.overview.md` and `.abstract.md` final updates (real endpoints, storage, dev workflow)
- A working stack, an end-to-end test that passes against real services, a populated store with sensible search results, and a doc anyone can follow to reproduce
