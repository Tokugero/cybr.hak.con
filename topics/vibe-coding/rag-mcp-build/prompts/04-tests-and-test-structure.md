# Step 04 — Tests and test structure

## What this step accomplishes (read this yourself)

You'll set up the test infrastructure that step 05 fills in with real assertions. No real implementation tests yet — those come from the TDD discipline in step 05a/b/c. This step creates the *places* tests live: directories per subsystem, fixture files for shared mocks, and the test commands wired into the role descriptions in `AGENTS.md`.

This is also where the **testing shapes and purpose** pattern from the talk lands. Different test shapes signal different things:

- **Unit tests** — one component, mocked dependencies. Fast. Catch logic bugs in isolation.
- **Integration tests** — one subsystem end-to-end with real internal dependencies, external dependencies mocked. Catch interface mismatches between modules.
- **Contract tests** — a subsystem's public interface tested against a fake but spec-compliant external (e.g. an in-memory Qdrant fake). Catch drift between what your code expects and what the dependency actually does.
- **End-to-end tests** — the whole stack with real services. Slow. Catch composition bugs that nothing else does. (Wired in step 06, not here.)

The assistant proposes the test layout based on the subsystems from step 02 and the stubs from step 03. You direct what shape mix is right for your project.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant set up step 04 of the build. The deliverable is the test infrastructure: directories, conftest fixtures, test commands wired into role descriptions, no real assertions yet.

Read `AGENTS.md`, the root `.overview.md`, and each subsystem's `.overview.md` first.

### Step 1 — interview the participant about test strategy

Ask, one at a time:

1. **What's the unit-vs-integration mix you want?** For the reference build: *"unit tests with mocks for the embedder and the vector store; one or two contract tests using an in-memory fake Qdrant; integration tests that exercise the chunker → embedder → store path with mocks at the external boundary; end-to-end is wired in step 06 with real services in docker-compose."* Honour the participant's answer.
2. **What's the test runner?** For Python with uv: pytest. For other stacks, ask.
3. **What shared fixtures will the subsystems need?** For the reference: *"a fake embedder that returns deterministic vectors, a fake vector store that holds documents in memory, sample chunks of HackTricks-shaped markdown."* Different scopes need different fixtures.

### Step 2 — propose the test layout

Show the participant the proposed directory and file structure. For the reference build, this is roughly:

```
<library>/
├── tests/
│   ├── __init__.py
│   ├── conftest.py             # shared fixtures: fake_embedder, fake_store, sample_chunks
│   ├── test_models.py          # Document, SearchResult schema validation
│   ├── test_chunker.py         # markdown chunking
│   ├── test_embedder.py        # OllamaEmbedder against a mocked HTTP layer
│   ├── test_store.py           # QdrantStore against a contract-fake
│   ├── test_search.py          # SearchService composition (embedder + store)
│   └── test_ingest.py          # Pipeline composition (chunker + embedder + store)

<api>/
├── tests/
│   ├── __init__.py
│   ├── conftest.py             # fixtures: TestClient, fake library service
│   ├── test_search_endpoint.py
│   └── test_mcp_tool.py
```

Each test file is empty (just `import pytest` plus a docstring). The fixtures are real — they get used in step 05.

Ask the participant: *"Anything to add, remove, or rename before I write these files?"*

### Step 3 — draft conftest contents

For each `conftest.py`, draft fixtures that match the interface decisions from step 03's subsystem `.overview.md`. For the reference build:

```python
# <library>/tests/conftest.py
import pytest
from typing import Iterable
# ... imports from the subsystem (skeleton interfaces only at this point)

@pytest.fixture
def fake_embedder():
    """Deterministic embedder: returns a vector derived from input text length."""
    # implementation: derives a 768-dim vector from input

@pytest.fixture
def fake_store():
    """In-memory vector store: holds documents and answers ANN queries by cosine similarity."""
    # implementation: dict-backed, brute-force cosine

@pytest.fixture
def sample_chunks():
    """Three short markdown chunks shaped like HackTricks pages."""
    # returns: list of strings
```

These fixtures don't need to work fully — they need stable interfaces. Step 05 wires them into real tests.

### Step 4 — update `AGENTS.md` and subsystem `.overview.md` files

Update the role descriptions in `AGENTS.md` with the test commands:

```markdown
### <library role>
... (existing content) ...

**Test commands:**
- Run tests: `cd <library>/ && uv run pytest`
- Run with coverage: `cd <library>/ && uv run pytest --cov`
```

Update each subsystem's `.overview.md` "Test commands" section with the same. Update each subsystem's component table to include the test files (initially empty rows under a "Tests" section).

### Step 5 — show, approve, write

Show the participant the test file tree, the conftest contents, and the updated AGENTS.md and `.overview.md` snippets. Ask: *"Anything to change before I write these?"* Iterate until approved. Write everything in one batch.

### Step 6 — stop

Do not write any real test assertions yet — that's step 05b. Do not proceed to step 05a. Wait for the participant to invoke `prompts/05a-skeleton-and-interface.md`.

## Outputs you'll have at the end of this step

- Test directories per subsystem with empty test files
- `conftest.py` per subsystem with the fixtures step 05 will use
- Test commands wired into `AGENTS.md` role descriptions and each subsystem's `.overview.md`
- A clear test shape strategy decision (unit / integration / contract / e2e mix) captured in the relevant `.overview.md`
