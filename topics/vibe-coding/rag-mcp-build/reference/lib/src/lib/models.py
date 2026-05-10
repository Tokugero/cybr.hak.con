from pydantic import BaseModel


class Document(BaseModel):
  id: str
  text: str
  source: str
  tags: list[str] = []


class SearchResult(BaseModel):
  document: Document
  score: float
