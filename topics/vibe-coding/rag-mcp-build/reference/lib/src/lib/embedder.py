from abc import ABC, abstractmethod

import httpx  # noqa: F401 — imported for callers to catch httpx.HTTPError


class EmbedderBase(ABC):
  @abstractmethod
  async def embed(self, text: str) -> list[float]: ...


class OllamaEmbedder(EmbedderBase):
  def __init__(self, base_url: str, model: str = "nomic-embed-text") -> None:
    self._base_url = base_url
    self._model = model

  async def embed(self, text: str) -> list[float]:
    # Raises httpx.HTTPError on network failure
    async with httpx.AsyncClient() as client:
      response = await client.post(
        f"{self._base_url}/api/embed",
        json={"model": self._model, "input": text},
      )
      response.raise_for_status()
      return response.json()["embeddings"][0]
