"""Pipeline composition: chunker + embedder + store."""
import pytest

from lib.ingest.pipeline import IngestPipeline, check_completeness
from lib.models import Document


class FakeSource:
  def __init__(self, docs):
    self._docs = docs

  def documents(self):
    return iter(self._docs)


class FakeChunker:
  def chunk(self, text: str) -> list[str]:
    return [text]


async def test_pipeline_run_stores_all_chunks_and_returns_count(fake_embedder, fake_store):
  docs = [
    Document(id="d1", text="alpha text", source="a.md"),
    Document(id="d2", text="beta text", source="b.md"),
  ]
  source = FakeSource(docs)
  chunker = FakeChunker()

  pipeline = IngestPipeline(chunker=chunker, embedder=fake_embedder, store=fake_store)
  result = await pipeline.run(source)

  assert result.chunks == 2
  assert result.skipped == 0
  assert result.sources == {"a.md", "b.md"}
  results = await fake_store.search(await fake_embedder.embed("alpha text"), top_k=5)
  assert any(r.document.text == "alpha text" for r in results)


async def test_pipeline_skips_already_indexed_source(fake_embedder, fake_store):
  pre_existing = Document(id="d1:0", text="alpha text", source="a.md")
  await fake_store.upsert([pre_existing], [await fake_embedder.embed("alpha text")])

  docs = [
    Document(id="d1", text="alpha text", source="a.md"),
    Document(id="d2", text="beta text", source="b.md"),
  ]
  source = FakeSource(docs)
  pipeline = IngestPipeline(chunker=FakeChunker(), embedder=fake_embedder, store=fake_store)
  result = await pipeline.run(source)

  assert result.skipped == 1
  assert result.chunks == 1
  assert result.sources == {"a.md", "b.md"}


def test_check_completeness_returns_sorted_missing():
  processed = {"a.md", "b.md", "c.md"}
  indexed = {"a.md", "c.md"}
  missing = check_completeness(processed, indexed)
  assert missing == ["b.md"]


def test_check_completeness_empty_when_complete():
  sources = {"a.md", "b.md"}
  assert check_completeness(sources, sources) == []


def test_check_completeness_ignores_extra_indexed():
  # Qdrant may have sources not in the current source set (e.g. deleted files); not an error
  processed = {"a.md"}
  indexed = {"a.md", "orphan.md"}
  assert check_completeness(processed, indexed) == []
