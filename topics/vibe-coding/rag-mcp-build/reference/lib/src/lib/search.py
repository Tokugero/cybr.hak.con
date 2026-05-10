from .embedder import EmbedderBase
from .models import SearchResult
from .store import VectorStoreBase


class SearchService:
  def __init__(self, embedder: EmbedderBase, store: VectorStoreBase) -> None:
    self._embedder = embedder
    self._store = store

  async def search(self, query: str, top_k: int = 10) -> list[SearchResult]:
    vector = await self._embedder.embed(query)
    return await self._store.search(vector, top_k=top_k)
