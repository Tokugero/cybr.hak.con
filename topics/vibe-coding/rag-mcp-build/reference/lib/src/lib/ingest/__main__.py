import asyncio
import os
import subprocess
import sys
from pathlib import Path

HACKTRICKS_PATH = os.environ.get("HACKTRICKS_PATH", "data/hacktricks")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
QDRANT_URL = os.environ.get("QDRANT_URL", "http://localhost:6333")
COLLECTION = os.environ.get("QDRANT_COLLECTION", "hacktricks")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
VECTOR_SIZE = int(os.environ.get("VECTOR_SIZE", "768"))


def _ensure_repo(path: Path) -> None:
  if path.exists():
    subprocess.run(["git", "-C", str(path), "pull", "--ff-only"], check=True)
    return
  repo_url = os.environ.get("HACKTRICKS_REPO_URL")
  if not repo_url:
    sys.exit(
      f"Directory {path} does not exist.\n"
      "Set HACKTRICKS_REPO_URL to clone it automatically, or clone it manually first."
    )
  subprocess.run(["git", "clone", "--depth=1", repo_url, str(path)], check=True)


async def main() -> None:
  from lib import (
    HackTricksSource,
    IngestPipeline,
    MarkdownChunker,
    OllamaEmbedder,
    QdrantStore,
  )
  from lib.ingest.pipeline import check_completeness

  path = Path(HACKTRICKS_PATH)
  _ensure_repo(path)

  store = QdrantStore(url=QDRANT_URL, collection=COLLECTION)
  await store.ensure_collection(vector_size=VECTOR_SIZE)

  source = HackTricksSource(repo_path=str(path))
  pipeline = IngestPipeline(
    chunker=MarkdownChunker(),
    embedder=OllamaEmbedder(base_url=OLLAMA_URL, model=EMBED_MODEL),
    store=store,
  )
  result = await pipeline.run(source)
  print(
    f"Ingested {result.chunks} chunks from {path} "
    f"({result.skipped} sources skipped, already indexed)"
  )

  indexed_sources = await store.list_sources()
  missing = check_completeness(result.sources, indexed_sources)
  if missing:
    for src in missing:
      print(f"MISSING: {src}", file=sys.stderr)
    print(
      f"Completion check FAILED: {len(missing)}/{len(result.sources)} sources not in Qdrant",
      file=sys.stderr,
    )
    sys.exit(1)
  print(f"Completion check passed: {len(indexed_sources)} sources indexed")


if __name__ == "__main__":
  asyncio.run(main())
