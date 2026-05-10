from collections.abc import Iterable
from pathlib import Path

from ...models import Document
from .base import SourceBase

_SKIP_NAMES = {"SUMMARY.md", "README.md"}


class HackTricksSource(SourceBase):
  def __init__(self, repo_path: str) -> None:
    self._repo_path = repo_path

  def documents(self) -> Iterable[Document]:
    root = Path(self._repo_path)
    for md_file in sorted(root.rglob("*.md")):
      if md_file.name in _SKIP_NAMES:
        continue
      if any(part.startswith(".") for part in md_file.parts):
        continue
      try:
        text = md_file.read_text(encoding="utf-8", errors="ignore")
      except OSError:
        continue
      if not text.strip():
        continue
      rel = md_file.relative_to(root)
      tags = list(rel.parts[:-1])
      yield Document(id=str(rel), text=text, source=str(rel), tags=tags)
