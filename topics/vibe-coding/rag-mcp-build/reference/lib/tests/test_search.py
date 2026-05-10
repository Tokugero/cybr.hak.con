"""SearchService composition: embedder + store."""
import pytest

from lib.models import Document
from lib.search import SearchService


async def test_search_returns_top_result_for_seeded_chunk(fake_embedder, fake_store, sample_chunks):
  # Load one chunk into the store via the same embedder path SearchService uses
  doc = Document(id="chunk_0", text=sample_chunks[0], source="hacktricks/priv-esc.md")
  vector = await fake_embedder.embed(doc.text)
  await fake_store.upsert([doc], [vector])

  service = SearchService(embedder=fake_embedder, store=fake_store)
  results = await service.search(query=sample_chunks[0], top_k=1)

  assert len(results) == 1
  assert results[0].document.id == "chunk_0"
  assert results[0].score > 0.99
