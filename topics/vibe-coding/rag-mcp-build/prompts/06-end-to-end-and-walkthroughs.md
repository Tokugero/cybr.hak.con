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

### Step 2 — propose docker-compose and Dockerfile

Propose:

```yaml
# docker-compose.yml at project root
services:
  qdrant:
    image: qdrant/qdrant:v1.13.0    # pin a specific version, never :latest
    ports:
      - "127.0.0.1:6333:6333"
    volumes:
      - qdrant-data:/qdrant/storage
  api:
    build: ./<api>
    profiles: [inference]    # only starts when --profile inference is set
    environment:
      QDRANT_URL: http://qdrant:6333
      OLLAMA_BASE_URL: ${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
    ports:
      - "127.0.0.1:8000:8000"
    depends_on:
      - qdrant
volumes:
  qdrant-data:
```

```dockerfile
# <api>/Dockerfile
FROM python:3.13-slim
RUN pip install uv
WORKDIR /app
COPY <api> /app/<api>
COPY <library> /app/<library>
RUN cd /app/<api> && uv sync --frozen --no-dev
EXPOSE 8000
CMD ["uv", "run", "uvicorn", "<api>.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

The `profiles: [inference]` keeps `docker compose up` from starting the API by default — Qdrant comes up alone for development; the API joins when explicitly requested. Adapt to the participant's preference.

Show the participant. Ask: *"Anything to change before I write these?"* Iterate. Write.

### Step 3 — write the end-to-end harness

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
    # Bring up qdrant via docker-compose (or assume it's already up)
    # Yield handles to the running services
    ...

def test_ingest_then_search(real_stack):
    # Use the real OllamaEmbedder and QdrantStore
    # Ingest a small fixture (e.g. 3 markdown docs)
    # Search for a known keyword
    # Assert the seeded doc comes back top-1
    ...
```

The test is opt-in (`RUN_E2E=1`) because it needs real Qdrant and real Ollama. The participant runs it manually as a check; CI doesn't unless they wire it. Discuss whether the harness should manage the stack lifecycle (`docker compose up -d` in setup, `down` in teardown) or assume it's running.

Show, approve, write.

### Step 4 — run the stack and the harness

```sh
docker compose up -d qdrant
RUN_E2E=1 cd <library>/ && uv run pytest tests/test_e2e.py -v
```

If the harness fails, debug. Common failure modes:
- Qdrant not reachable — check container is up, port 6333 is bound to localhost.
- Ollama not reachable — Ollama runs outside Docker by default; the API container talks to `host.docker.internal:11434` on Mac/Windows, requires extra-hosts on Linux.
- Embedding dimension mismatch — `nomic-embed-text` produces 768-dim vectors; the Qdrant collection must be created with `size=768`.

If the participant's environment doesn't have Ollama or the right embedding model pulled, point them at the workshop README's prerequisites.

### Step 5 — write `docs/walkthrough.md`

Short doc for humans. Format:

```markdown
# Walkthrough: confirming the build works

## Prerequisites
- Docker with Compose v2
- Ollama running with `nomic-embed-text` pulled
- Python 3.13 + uv

## Bring up the stack
```sh
docker compose up -d qdrant
```

## Ingest a small fixture
```sh
cd <library>/ && uv run python -m <library>.ingest hacktricks --skip-tags --limit 5
```

This clones HackTricks (~200 MB), processes the first 5 files only, embeds them, and writes to Qdrant.

## Run a search
```sh
curl -s 'http://localhost:8000/search?q=Apache+2.4.49' | jq .
```

Expected: a JSON response with at least one result whose `text` mentions CVE-2021-41773.

## Tear down
```sh
docker compose down
```

## What this proves
The full pipeline (chunker → embedder → store → search) is connected end-to-end with real services. If this works, the build is correct in shape. If you change a subsystem, re-run this walkthrough as a smoke check.
```

Show, approve, write.

### Step 6 — final updates to root `.overview.md`

- Service endpoints section: fill in real URLs (Qdrant at 127.0.0.1:6333; API at 127.0.0.1:8000).
- Dev workflow section: add the docker-compose and walkthrough commands.
- Storage section: note Qdrant data lives in the `qdrant-data` volume.

Update `.abstract.md` if anything in the subsystem table shifted.

### Step 7 — note the tool-specific final step

Tell the participant explicitly:

> The build is workshop-complete. Wiring the running MCP server into your AI tool is a tool-specific step that lives in the workshop README's "Tool-specific final step" section. It's not in this prompt because the right action depends on which tool you're using:
>
> - Claude Code: add the server to `.mcp.json`
> - OpenCode: add to `opencode.json` under `mcpServers`
> - Cursor / Codex / other: use whatever your tool's MCP support looks like, or hit the HTTP endpoint directly
>
> Once wired, your assistant can call the search tool to look up HackTricks techniques without you having to copy-paste anything from the source.

### Step 8 — stop

The workshop is done. Congratulate the participant. Suggest two things they might do next (both optional):

1. Run the full ingestion (`--limit 5` produces a tiny corpus; removing the limit ingests all of HackTricks, ~hours on CPU embeddings) and use the MCP tool against it for real work.
2. Apply the same patterns to a project they're already working on — the talk's closing first step is `.abstract.md` for an existing project.

## Outputs you'll have at the end of this step

- An SRE cross-system review (in conversation; or persisted to `docs/.tmp/sre-review-<date>.md` if the participant asks)
- `docker-compose.yml` and the API `Dockerfile`
- `<library>/tests/test_e2e.py` (or equivalent), opt-in via `RUN_E2E=1`
- `docs/walkthrough.md` for human verification
- Root `.overview.md` and `.abstract.md` final updates (real endpoints, storage, dev workflow)
- A working stack, an end-to-end test that passes, and a doc anyone can follow to reproduce
