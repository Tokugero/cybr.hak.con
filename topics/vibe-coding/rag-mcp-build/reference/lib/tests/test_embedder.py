"""OllamaEmbedder against a mocked HTTP layer."""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from lib.embedder import OllamaEmbedder


async def test_embed_posts_to_ollama_and_returns_vector():
  vector = [0.1, 0.2, 0.3]
  mock_response = MagicMock()
  mock_response.raise_for_status = MagicMock()
  mock_response.json.return_value = {"embeddings": [vector]}

  mock_post = AsyncMock(return_value=mock_response)

  with patch("lib.embedder.httpx.AsyncClient") as mock_client_cls:
    mock_client_cls.return_value.__aenter__ = AsyncMock(
      return_value=MagicMock(post=mock_post)
    )
    mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=False)

    embedder = OllamaEmbedder(base_url="http://localhost:11434")
    result = await embedder.embed("hello")

  mock_post.assert_called_once()
  call_kwargs = mock_post.call_args
  assert "/api/embed" in call_kwargs.args[0]
  assert call_kwargs.kwargs["json"]["model"] == "nomic-embed-text"
  assert call_kwargs.kwargs["json"]["input"] == "hello"
  assert result == vector
