import math

import pytest

from lib.models import Document, SearchResult


@pytest.fixture
def fake_embedder():
  """Deterministic embedder: 768-dim vector derived from input text length."""
  class FakeEmbedder:
    async def embed(self, text: str) -> list[float]:
      seed = len(text) % 768
      vec = [math.sin(seed + i) for i in range(768)]
      mag = math.sqrt(sum(v * v for v in vec))
      return [v / mag for v in vec]
  return FakeEmbedder()


@pytest.fixture
def fake_store():
  """In-memory store backed by a list; brute-force cosine similarity."""
  class FakeStore:
    def __init__(self):
      self._data: list[tuple[list[float], Document]] = []

    async def upsert(self, docs: list[Document], vectors: list[list[float]]) -> None:
      for doc, vec in zip(docs, vectors):
        self._data.append((vec, doc))

    async def search(self, query_vector: list[float], top_k: int = 10) -> list[SearchResult]:
      def cosine(a, b):
        dot = sum(x * y for x, y in zip(a, b))
        mag_a = math.sqrt(sum(x * x for x in a))
        mag_b = math.sqrt(sum(x * x for x in b))
        return dot / (mag_a * mag_b) if mag_a and mag_b else 0.0
      scored = [(cosine(query_vector, vec), doc) for vec, doc in self._data]
      scored.sort(key=lambda x: x[0], reverse=True)
      return [SearchResult(document=doc, score=score) for score, doc in scored[:top_k]]

    async def has_source(self, source: str) -> bool:
      return any(doc.source == source for _, doc in self._data)

    async def list_sources(self) -> set[str]:
      return {doc.source for _, doc in self._data}

  return FakeStore()


@pytest.fixture
def sample_chunks():
  """Three short markdown chunks shaped like HackTricks pages."""
  return [
    "# Linux Privilege Escalation\n\nCheck SUID binaries: `find / -perm -4000 2>/dev/null`",
    "# SQL Injection\n\nBasic payload: `' OR '1'='1`. Use sqlmap for automated testing.",
    "# XSS\n\nReflected XSS: inject `<script>alert(1)</script>` into user-controlled parameters.",
  ]
