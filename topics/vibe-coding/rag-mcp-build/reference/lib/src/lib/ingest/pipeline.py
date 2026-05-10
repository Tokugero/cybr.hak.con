from typing import NamedTuple

from ..chunker import ChunkerBase
from ..embedder import EmbedderBase
from ..store import VectorStoreBase
from .sources.base import SourceBase


class IngestResult(NamedTuple):
  chunks: int
  sources: set[str]
  skipped: int


def check_completeness(processed: set[str], indexed: set[str]) -> list[str]:
  return sorted(processed - indexed)


class IngestPipeline:
  def __init__(
    self,
    chunker: ChunkerBase,
    embedder: EmbedderBase,
    store: VectorStoreBase,
  ) -> None:
    self._chunker = chunker
    self._embedder = embedder
    self._store = store

  async def run(self, source: SourceBase) -> IngestResult:
    total = 0
    skipped = 0
    processed_sources: set[str] = set()
    for doc in source.documents():
      processed_sources.add(doc.source)
      if await self._store.has_source(doc.source):
        skipped += 1
        continue
      texts = list(self._chunker.chunk(doc.text))
      vectors = [await self._embedder.embed(t) for t in texts]
      chunk_docs = [
        doc.__class__(id=f"{doc.id}:{i}", text=t, source=doc.source)
        for i, t in enumerate(texts)
      ]
      await self._store.upsert(chunk_docs, vectors)
      total += len(chunk_docs)
    return IngestResult(chunks=total, sources=processed_sources, skipped=skipped)
