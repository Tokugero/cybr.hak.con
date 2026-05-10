from pydantic import BaseModel


class SearchResultDTO(BaseModel):
  text: str
  source: str
  score: float


class SearchResponse(BaseModel):
  results: list[SearchResultDTO]
