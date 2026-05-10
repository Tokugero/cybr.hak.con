import uuid
from abc import ABC, abstractmethod

from .models import Document, SearchResult


class VectorStoreBase(ABC):
  @abstractmethod
  async def upsert(self, docs: list[Document], vectors: list[list[float]]) -> None: ...

  @abstractmethod
  async def search(self, vector: list[float], top_k: int = 10) -> list[SearchResult]: ...

  @abstractmethod
  async def has_source(self, source: str) -> bool: ...

  @abstractmethod
  async def list_sources(self) -> set[str]: ...


class QdrantStore(VectorStoreBase):
  def __init__(self, url: str, collection: str, *, client=None) -> None:
    self._collection = collection
    if client is None:
      from qdrant_client import AsyncQdrantClient
      self._client = AsyncQdrantClient(url=url)
    else:
      self._client = client

  async def ensure_collection(self, vector_size: int) -> None:
    from qdrant_client.models import Distance, VectorParams
    result = await self._client.get_collections()
    existing = {c.name for c in result.collections}
    if self._collection not in existing:
      await self._client.create_collection(
        collection_name=self._collection,
        vectors_config=VectorParams(size=vector_size, distance=Distance.COSINE),
      )

  _UPSERT_BATCH = 50

  async def upsert(self, docs: list[Document], vectors: list[list[float]]) -> None:
    from qdrant_client.models import PointStruct
    points = [
      PointStruct(
        id=str(uuid.uuid5(uuid.NAMESPACE_URL, doc.id)),
        vector=vector,
        payload={"id": doc.id, "text": doc.text, "source": doc.source, "tags": doc.tags},
      )
      for doc, vector in zip(docs, vectors)
    ]
    for i in range(0, max(len(points), 1), self._UPSERT_BATCH):
      batch = points[i : i + self._UPSERT_BATCH]
      if batch:
        await self._client.upsert(collection_name=self._collection, points=batch)

  async def search(self, vector: list[float], top_k: int = 10) -> list[SearchResult]:
    result = await self._client.query_points(
      collection_name=self._collection,
      query=vector,
      limit=top_k,
    )
    return [
      SearchResult(
        document=Document(
          id=hit.payload.get("id", str(hit.id)),
          text=hit.payload["text"],
          source=hit.payload["source"],
          tags=hit.payload.get("tags", []),
        ),
        score=hit.score,
      )
      for hit in result.points
    ]

  async def has_source(self, source: str) -> bool:
    from qdrant_client.models import FieldCondition, Filter, MatchValue
    points, _ = await self._client.scroll(
      collection_name=self._collection,
      scroll_filter=Filter(must=[FieldCondition(key="source", match=MatchValue(value=source))]),
      limit=1,
      with_payload=False,
      with_vectors=False,
    )
    return len(points) > 0

  async def list_sources(self) -> set[str]:
    sources: set[str] = set()
    offset = None
    while True:
      points, offset = await self._client.scroll(
        collection_name=self._collection,
        limit=1000,
        offset=offset,
        with_payload=["source"],
        with_vectors=False,
      )
      for point in points:
        if "source" in point.payload:
          sources.add(point.payload["source"])
      if offset is None:
        break
    return sources
