"""Markdown chunking logic."""
import pytest

from lib.chunker import MarkdownChunker


def test_multi_section_doc_splits_at_headings():
  text = (
    "# Section One\n\nContent for section one.\n\n"
    "# Section Two\n\nContent for section two."
  )
  chunker = MarkdownChunker(max_chars=1000)
  chunks = list(chunker.chunk(text))

  assert len(chunks) == 2
  assert chunks[0].startswith("# Section One")
  assert chunks[1].startswith("# Section Two")


def test_section_over_max_chars_splits_at_paragraphs():
  # heading(13) + para_a(43) = 58 chars; adding para_b pushes to 103 > max_chars
  heading = "# Big Section"
  para_a = "A: " + "x" * 40
  para_b = "B: " + "x" * 40
  text = f"{heading}\n\n{para_a}\n\n{para_b}"

  chunker = MarkdownChunker(max_chars=80)
  chunks = list(chunker.chunk(text))

  assert len(chunks) == 2
  assert all(len(c) <= 80 for c in chunks)


def test_oversized_single_paragraph_is_split_by_lines():
  # A single paragraph (e.g. a large code block) that exceeds max_chars must be split
  line = "x" * 40
  big_paragraph = "\n".join([line] * 10)  # 409 chars, well over max_chars=100
  text = f"# Section\n\n{big_paragraph}"

  chunker = MarkdownChunker(max_chars=100)
  chunks = list(chunker.chunk(text))

  assert len(chunks) > 1
  assert all(len(c) <= 100 for c in chunks)


def test_oversized_single_line_is_hard_truncated():
  # A line longer than max_chars is truncated to max_chars
  big_line = "y" * 200
  text = f"# Section\n\n{big_line}"

  chunker = MarkdownChunker(max_chars=100)
  chunks = list(chunker.chunk(text))

  assert all(len(c) <= 100 for c in chunks)
