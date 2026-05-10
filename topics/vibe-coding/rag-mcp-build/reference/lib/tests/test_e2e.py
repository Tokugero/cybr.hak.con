"""End-to-end: real Qdrant + real Ollama. Opt-in via RUN_E2E=1."""
import os

import pytest

pytestmark = pytest.mark.skipif(
  os.environ.get("RUN_E2E") != "1",
  reason="set RUN_E2E=1 to run end-to-end tests",
)

_COLLECTION = "e2e-test"
_QDRANT_URL = os.environ.get("QDRANT_URL", "http://localhost:6333")
_OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
_EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
_VECTOR_SIZE = int(os.environ.get("VECTOR_SIZE", "768"))

_FIXTURE_DOCS = [
  ("fixture/sqli.md", "# SQL Injection\n\nUse `' OR 1=1 --` to bypass login forms.", ["fixture"]),
  ("fixture/xss.md", "# Cross-Site Scripting\n\nInject `<script>alert(1)</script>` into input fields.", ["fixture"]),
  ("fixture/lfi.md", "# Local File Inclusion\n\nRead `/etc/passwd` via `?page=../../../../etc/passwd`.", ["fixture"]),
]


class _FixtureSource:
  def documents(self):
    from lib import Document
    for path, text, tags in _FIXTURE_DOCS:
      yield Document(id=path, text=text, source=path, tags=tags)


@pytest.fixture(scope="module")
async def real_store():
  from lib import QdrantStore
  store = QdrantStore(url=_QDRANT_URL, collection=_COLLECTION)
  await store.ensure_collection(vector_size=_VECTOR_SIZE)
  yield store
  from qdrant_client import AsyncQdrantClient
  await AsyncQdrantClient(url=_QDRANT_URL).delete_collection(_COLLECTION)


@pytest.fixture(scope="module")
def real_embedder():
  from lib import OllamaEmbedder
  return OllamaEmbedder(base_url=_OLLAMA_URL, model=_EMBED_MODEL)


async def test_ingest_then_search(real_store, real_embedder):
  from lib import IngestPipeline, MarkdownChunker

  pipeline = IngestPipeline(
    chunker=MarkdownChunker(),
    embedder=real_embedder,
    store=real_store,
  )
  count = await pipeline.run(_FixtureSource())
  assert count >= len(_FIXTURE_DOCS)

  vector = await real_embedder.embed("SQL injection bypass login")
  results = await real_store.search(vector, top_k=3)
  assert len(results) > 0
  sources = [r.document.source for r in results]
  assert any("sqli" in s for s in sources)
