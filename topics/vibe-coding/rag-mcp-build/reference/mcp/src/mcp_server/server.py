from fastmcp import FastMCP

from .schemas import SearchResponse, SearchResultDTO

mcp = FastMCP("rag-search")

_service = None


async def _search_impl(query: str, top_k: int = 10) -> SearchResponse:
  hits = await _service.search(query, top_k)
  return SearchResponse(
    results=[
      SearchResultDTO(text=h.document.text, source=h.document.source, score=h.score)
      for h in hits
    ]
  )


search = mcp.tool(name="search")(_search_impl)


def main() -> None:
  import os
  global _service
  from lib import OllamaEmbedder, QdrantStore, SearchService

  _service = SearchService(
    embedder=OllamaEmbedder(
      base_url=os.environ.get("OLLAMA_URL", "http://localhost:11434"),
      model=os.environ.get("EMBED_MODEL", "nomic-embed-text"),
    ),
    store=QdrantStore(
      url=os.environ.get("QDRANT_URL", "http://localhost:6333"),
      collection=os.environ.get("QDRANT_COLLECTION", "hacktricks"),
    ),
  )
  mcp.run()
