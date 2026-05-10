"""HackTricksSource document iteration."""
import pytest

from lib.ingest.sources.hacktricks import HackTricksSource


def _write(path, text):
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(text, encoding="utf-8")


def test_yields_markdown_files_with_tags(tmp_path):
  _write(tmp_path / "linux-hardening" / "privesc.md", "# PrivEsc\n\nContent here.")
  _write(tmp_path / "pentesting-web" / "sqli.md", "# SQLi\n\nPayloads.")

  source = HackTricksSource(repo_path=str(tmp_path))
  docs = list(source.documents())

  ids = {d.id for d in docs}
  assert "linux-hardening/privesc.md" in ids
  assert "pentesting-web/sqli.md" in ids

  privesc = next(d for d in docs if "privesc" in d.id)
  assert privesc.tags == ["linux-hardening"]
  assert "PrivEsc" in privesc.text


def test_skips_summary_and_readme(tmp_path):
  _write(tmp_path / "SUMMARY.md", "# Summary\n\nThis is a ToC.")
  _write(tmp_path / "README.md", "# Readme\n\nIntro.")
  _write(tmp_path / "topic" / "page.md", "# Real content.")

  source = HackTricksSource(repo_path=str(tmp_path))
  docs = list(source.documents())

  ids = {d.id for d in docs}
  assert not any("SUMMARY" in i or "README" in i for i in ids)
  assert "topic/page.md" in ids


def test_skips_hidden_directories(tmp_path):
  _write(tmp_path / ".git" / "COMMIT_EDITMSG", "initial commit")
  _write(tmp_path / "topic" / "page.md", "# Content.")

  source = HackTricksSource(repo_path=str(tmp_path))
  docs = list(source.documents())

  assert all(".git" not in d.id for d in docs)


def test_skips_empty_files(tmp_path):
  _write(tmp_path / "topic" / "empty.md", "   \n  ")
  _write(tmp_path / "topic" / "real.md", "# Content.")

  source = HackTricksSource(repo_path=str(tmp_path))
  docs = list(source.documents())

  assert all("empty" not in d.id for d in docs)
