import pytest

from lib.models import Document, SearchResult


@pytest.fixture
def fake_library():
  """Fake SearchService: returns deterministic SearchResult objects."""
  class FakeLibrary:
    async def search(self, query: str, top_k: int = 10) -> list[SearchResult]:
      return [
        SearchResult(
          document=Document(
            id=f"doc_{i}",
            text=f"result_{i}_for_{query}",
            source=f"hacktricks/doc_{i}.md",
          ),
          score=round(1.0 - i * 0.1, 1),
        )
        for i in range(top_k)
      ]
  return FakeLibrary()
