"""MCP search endpoint tests."""
import pytest

import mcp_server.server as srv
from mcp_server.schemas import SearchResponse


async def test_search_returns_dto_list_for_query(fake_library, monkeypatch):
  monkeypatch.setattr(srv, "_service", fake_library)

  response = await srv._search_impl(query="xss", top_k=2)

  assert isinstance(response, SearchResponse)
  assert len(response.results) == 2
  assert response.results[0].text == "result_0_for_xss"
  assert response.results[0].source == "hacktricks/doc_0.md"
  assert response.results[0].score == pytest.approx(1.0)
