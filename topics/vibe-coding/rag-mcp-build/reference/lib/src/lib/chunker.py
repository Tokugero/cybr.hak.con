import re
from abc import ABC, abstractmethod
from collections.abc import Iterable


class ChunkerBase(ABC):
  @abstractmethod
  def chunk(self, text: str) -> Iterable[str]: ...


class MarkdownChunker(ChunkerBase):
  def __init__(self, max_chars: int = 1000) -> None:
    self._max_chars = max_chars

  def chunk(self, text: str) -> Iterable[str]:
    sections = re.split(r'(?=^#{1,6} )', text, flags=re.MULTILINE)
    for section in sections:
      section = section.strip()
      if not section:
        continue
      if len(section) <= self._max_chars:
        yield section
      else:
        yield from self._split_by_paragraph(section)

  def _split_by_paragraph(self, text: str) -> Iterable[str]:
    paragraphs = [p.strip() for p in text.split('\n\n') if p.strip()]
    current: list[str] = []
    current_len = 0
    for para in paragraphs:
      if len(para) > self._max_chars:
        if current:
          yield '\n\n'.join(current)
          current = []
          current_len = 0
        yield from self._split_oversized(para)
        continue
      joined_len = current_len + (2 if current else 0) + len(para)
      if current and joined_len > self._max_chars:
        yield '\n\n'.join(current)
        current = [para]
        current_len = len(para)
      else:
        current.append(para)
        current_len = joined_len
    if current:
      yield '\n\n'.join(current)

  def _split_oversized(self, text: str) -> Iterable[str]:
    lines = text.split('\n')
    current: list[str] = []
    current_len = 0
    for line in lines:
      line = line[:self._max_chars]  # hard-truncate any single line that exceeds limit
      joined_len = current_len + (1 if current else 0) + len(line)
      if current and joined_len > self._max_chars:
        yield '\n'.join(current)
        current = [line]
        current_len = len(line)
      else:
        current.append(line)
        current_len = joined_len
    if current:
      yield '\n'.join(current)
