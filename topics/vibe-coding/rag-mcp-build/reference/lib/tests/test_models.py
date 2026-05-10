"""Document and SearchResult schema validation."""
import pytest
from pydantic import ValidationError

from lib.models import Document, SearchResult


def test_document_tags_defaults_to_empty_list():
  doc = Document(id="d1", text="hello", source="file.md")
  assert doc.tags == []


def test_document_requires_all_three_fields():
  with pytest.raises(ValidationError):
    Document(text="hello", source="file.md")  # missing id


def test_search_result_nests_document_and_score():
  doc = Document(id="d1", text="hello", source="file.md")
  result = SearchResult(document=doc, score=0.95)
  assert result.document.id == "d1"
  assert result.score == pytest.approx(0.95)
