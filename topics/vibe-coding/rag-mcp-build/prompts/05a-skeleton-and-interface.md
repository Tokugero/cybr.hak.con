# Step 05a — Skeleton and interface

## What this step accomplishes (read this yourself)

This is the first of three TDD checkpoints. Before any real code, you commit to the *interfaces* — the public ABCs, the data models, the function signatures. The discipline is the same one in the speaker's `tdd` skill: confirm interface, confirm behaviours, then red, then green. This step is the "confirm interface" gate.

You're paying upfront for confidence. Once interfaces are agreed, step 05b writes a failing test against them and step 05c iterates over features. If you skip 05a and let the assistant invent interfaces as it goes, every later test is a guess at what the code should expose, and the project drifts.

The assistant proposes interfaces, you confirm or redirect, the assistant writes skeleton modules with the agreed signatures (raising `NotImplementedError` or returning sensible defaults). The `.overview.md` Exports column gets populated as files land — this is the function-signature-index-in-component-table pattern in action.

No tests with real assertions yet. No real implementation. Skeletons + agreed interfaces only.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant set up step 05a of the build. The deliverable is module skeletons with agreed-upon interfaces and updated `.overview.md` Exports columns.

Read `AGENTS.md`, the root `.overview.md`, and each subsystem's `.overview.md` first. Note any existing component-table rows from step 04 (test files); they stay.

### Step 1 — propose interfaces by subsystem

For each subsystem, propose:
- The public ABCs / Protocols (in Python: `abc.ABC` or `typing.Protocol`).
- The data models (Pydantic for the reference; whatever the participant's stack uses).
- The function or method signatures users of the subsystem will call.

For the reference build's library subsystem, that's roughly:

```python
# <library>/src/<library>/models.py
class Document(BaseModel):
    id: str
    text: str
    source: str
    tags: list[str] = []

class SearchResult(BaseModel):
    document: Document
    score: float

# <library>/src/<library>/embedder.py
class EmbedderBase(ABC):
    @abstractmethod
    async def embed(self, text: str) -> list[float]: ...

class OllamaEmbedder(EmbedderBase):
    def __init__(self, base_url: str, model: str = "nomic-embed-text"): ...
    async def embed(self, text: str) -> list[float]: ...

# <library>/src/<library>/store.py
class VectorStoreBase(ABC):
    @abstractmethod
    async def upsert(self, docs: list[Document], vectors: list[list[float]]) -> None: ...
    @abstractmethod
    async def search(self, vector: list[float], top_k: int = 10) -> list[SearchResult]: ...

# <library>/src/<library>/search.py
class SearchService:
    def __init__(self, embedder: EmbedderBase, store: VectorStoreBase): ...
    async def search(self, query: str, top_k: int = 10) -> list[SearchResult]: ...

# <library>/src/<library>/chunker.py
class ChunkerBase(ABC):
    @abstractmethod
    def chunk(self, text: str) -> Iterable[str]: ...
```

For the API subsystem:

```python
# <api>/src/<api>/main.py
app: FastAPI

# <api>/src/<api>/schemas.py
class SearchRequest(BaseModel): query: str; top_k: int = 10
class SearchResponse(BaseModel): results: list[SearchResultDTO]

# <api>/src/<api>/mcp/server.py
mcp: FastMCP
```

If the participant has a different stack or scope, adapt the proposal. Show the participant. Ask: *"Are these the interfaces you want? Anything to rename, change the signature of, or split differently?"*

The interfaces get debated here, not later. Press the participant on:
- **Async vs sync.** Inconsistent choice causes integration pain later. For the reference build, async throughout the I/O path (embed, search, upsert).
- **Where dependencies are injected.** Constructor injection (recommended) vs hidden globals.
- **Error types.** What does `embed()` raise on a network failure? What does `search()` return on no matches?

Iterate until the participant agrees on the full interface surface.

Before moving to step 2, force three specific design decisions that crash builds when left implicit:

**Return shape of the search response.** Naive chunk text forces the calling LLM agent to load whole source documents to recover structure. A structured response (e.g. `tool`, `usage`, `options`, `install`, `source_path`) lets the agent act on the result directly. Ask: *"what fields belong in the response so the calling agent can use the result without re-loading the source?"* Capture the chosen shape in `SearchResult` (or the response DTO equivalent).

**Chunker behaviour when a unit exceeds chunk_size.** Real source content has code blocks, command output dumps, and tables that are larger than typical prose paragraphs. The chunker must have an explicit cascade — for the reference build: section (markdown heading) → paragraph → line → hard size cut. The cascade is the guarantee that no input shape crashes ingestion. Ask: *"what does the chunker do when a paragraph is bigger than chunk_size? When a line is bigger than chunk_size?"* If the participant only describes paragraph splitting, push back — ingestion against real source will crash on the first oversized paragraph.

**Resumability and completeness contract on the vector store.** Per the commitment from step 02. The store interface must expose at least `has_source(source) -> bool` (so the pipeline can skip already-ingested sources) and `list_sources() -> set[str]` (so a completion check can compare processed vs indexed). The ingest pipeline returns enough state to run that check at end-of-run. Ask: *"what's the public surface on the store that lets the pipeline resume after a crash and verify it actually finished?"*

For high-drift external clients (Qdrant client, Ollama client), per `protocols.md`'s live-library-surface rule, run a quick `help(...)` or `dir(...)` check against the installed version before writing call sites. Write against what's there, not what memory suggests.

### Step 2 — write skeleton modules

Once the interfaces are agreed, write skeleton files. Each method body is `raise NotImplementedError` or returns a sensible default; the *signature* is what matters at this stage. Imports, type annotations, ABCs, Pydantic models are all real.

Suggested file layout for the reference build:

```
<library>/
├── src/<library>/
│   ├── __init__.py
│   ├── models.py
│   ├── embedder.py
│   ├── store.py
│   ├── chunker.py
│   ├── search.py
│   └── ingest/
│       ├── __init__.py
│       ├── pipeline.py
│       └── sources/
│           ├── __init__.py
│           ├── base.py
│           └── hacktricks.py
└── pyproject.toml

<api>/
├── src/<api>/
│   ├── __init__.py
│   ├── main.py
│   ├── schemas.py
│   └── mcp/
│       ├── __init__.py
│       └── server.py
└── pyproject.toml
```

Each `pyproject.toml` is a minimal uv-compatible package definition with the deps the interfaces actually need (pydantic, httpx, qdrant-client for the library; fastapi, fastmcp, the library itself for the api).

### Step 3 — populate `.overview.md` Exports column

For each subsystem's `.overview.md`, fill in the component table's Exports column with the public symbols from each module:

```markdown
| Path | Type | Purpose | Exports | Deps |
|------|------|---------|---------|------|
| `src/<library>/models.py` | models | Document and SearchResult schemas | `Document`, `SearchResult` | pydantic |
| `src/<library>/embedder.py` | abc+impl | EmbedderBase, OllamaEmbedder | `EmbedderBase`, `OllamaEmbedder` | httpx |
| `src/<library>/store.py` | abc | VectorStoreBase | `VectorStoreBase` | — |
| ... | | | | |
```

The Exports column *is* the function signature index. Future sessions read it to know what's available without grep-ing the code.

### Step 4 — show, approve, write

Show the participant the proposed skeleton tree, the contents of each module's `__init__.py` with public re-exports, and the updated `.overview.md` files. Ask: *"Anything to change before I write these?"* Iterate. Write everything in one batch.

After writing, run a quick smoke check: `cd <library>/ && uv sync && uv run python -c "import <library>"` (and the same for the API). The interfaces should import cleanly even though no method bodies are filled in.

### Step 5 — stop

Do not write any tests with real assertions. Do not implement any method bodies. Wait for the participant to invoke `prompts/05b-first-red-green.md`.

## Outputs you'll have at the end of this step

- Module skeletons in each subsystem with real type signatures and ABCs
- `__init__.py` files with public re-exports
- Each subsystem's `.overview.md` Exports column populated
- A clean import smoke check (the skeleton compiles and imports)
- Interface decisions captured in writing — the next two steps work against agreed contracts
