"""MCP tool registration and dispatch tests."""
import pytest

import mcp_server.server as srv
from mcp_server.schemas import SearchResponse


async def test_search_tool_is_registered():
  tools = await srv.mcp.get_tools()
  assert "search" in tools


async def test_search_tool_dispatches_and_returns_search_response(fake_library, monkeypatch):
  monkeypatch.setattr(srv, "_service", fake_library)

  tools = await srv.mcp.get_tools()
  result = await tools["search"].run({"query": "sqli", "top_k": 3})

  data = result.content[0].text if hasattr(result.content[0], "text") else str(result)
  assert "sqli" in data
