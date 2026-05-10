"""QdrantStore against in-memory contract-fake."""
import sys
import pytest
from unittest.mock import AsyncMock, MagicMock

from lib.models import Document
from lib.store import QdrantStore


@pytest.fixture(autouse=True)
def patch_qdrant(monkeypatch):
  fake_models = MagicMock()
  fake_models.PointStruct = MagicMock(side_effect=lambda **kw: kw)
  fake_models.Filter = MagicMock(side_effect=lambda **kw: kw)
  fake_models.FieldCondition = MagicMock(side_effect=lambda **kw: kw)
  fake_models.MatchValue = MagicMock(side_effect=lambda **kw: kw)
  monkeypatch.setitem(sys.modules, "qdrant_client", MagicMock())
  monkeypatch.setitem(sys.modules, "qdrant_client.models", fake_models)
  return fake_models


async def test_upsert_then_search_returns_ranked_results():
  mock_client = AsyncMock()
  hit = MagicMock()
  hit.id = "doc1"
  hit.score = 0.85
  hit.payload = {"text": "hello", "source": "file.md", "tags": []}
  query_result = MagicMock()
  query_result.points = [hit]
  mock_client.query_points.return_value = query_result

  store = QdrantStore(url="http://localhost:6333", collection="rag", client=mock_client)
  doc = Document(id="doc1", text="hello", source="file.md")
  await store.upsert([doc], [[0.1, 0.2, 0.3]])

  mock_client.upsert.assert_called_once()
  upsert_kwargs = mock_client.upsert.call_args.kwargs
  assert upsert_kwargs["collection_name"] == "rag"

  results = await store.search([0.1, 0.2, 0.3], top_k=1)
  mock_client.query_points.assert_called_once_with(
    collection_name="rag",
    query=[0.1, 0.2, 0.3],
    limit=1,
  )
  assert len(results) == 1
  assert results[0].document.id == "doc1"
  assert results[0].score == pytest.approx(0.85)


async def test_has_source_returns_true_when_present():
  mock_client = AsyncMock()
  mock_point = MagicMock()
  mock_client.scroll.return_value = ([mock_point], None)

  store = QdrantStore(url="http://localhost:6333", collection="rag", client=mock_client)
  assert await store.has_source("file.md") is True
  mock_client.scroll.assert_called_once()
  call_kwargs = mock_client.scroll.call_args.kwargs
  assert call_kwargs["collection_name"] == "rag"
  assert call_kwargs["limit"] == 1


async def test_has_source_returns_false_when_absent():
  mock_client = AsyncMock()
  mock_client.scroll.return_value = ([], None)

  store = QdrantStore(url="http://localhost:6333", collection="rag", client=mock_client)
  assert await store.has_source("missing.md") is False


async def test_list_sources_paginates_and_collects_all():
  mock_client = AsyncMock()

  def make_point(src):
    p = MagicMock()
    p.payload = {"source": src}
    return p

  # Two pages: first returns offset "page2", second returns None (done)
  mock_client.scroll.side_effect = [
    ([make_point("a.md"), make_point("b.md")], "page2"),
    ([make_point("c.md")], None),
  ]

  store = QdrantStore(url="http://localhost:6333", collection="rag", client=mock_client)
  sources = await store.list_sources()

  assert sources == {"a.md", "b.md", "c.md"}
  assert mock_client.scroll.call_count == 2
  # Second call passes the offset returned by first
  second_call_kwargs = mock_client.scroll.call_args_list[1].kwargs
  assert second_call_kwargs["offset"] == "page2"


async def test_list_sources_skips_points_without_source_key():
  mock_client = AsyncMock()
  good = MagicMock()
  good.payload = {"source": "a.md"}
  bad = MagicMock()
  bad.payload = {}
  mock_client.scroll.return_value = ([good, bad], None)

  store = QdrantStore(url="http://localhost:6333", collection="rag", client=mock_client)
  sources = await store.list_sources()
  assert sources == {"a.md"}
