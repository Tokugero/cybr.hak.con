# Walkthrough: confirming the build works

## Prerequisites

- Docker with Compose v2 (`docker compose version`)
- Ollama running locally with `nomic-embed-text` pulled (`ollama pull nomic-embed-text`)
- Python 3.13 + uv (`uv --version`)

## Bring up the stack

```sh
docker compose up -d qdrant
```

Qdrant binds to `127.0.0.1:6333`. Ollama runs on the host at `http://localhost:11434`.

## Ingest a small fixture (end-to-end test)

```sh
cd lib && RUN_E2E=1 uv run pytest tests/test_e2e.py -v
```

This creates a temporary `e2e-test` Qdrant collection, ingests 3 markdown fixture docs, searches for "SQL injection bypass login", asserts the SQLi doc comes back top-3, then deletes the collection on teardown.

Expected output:
```
tests/test_e2e.py::test_ingest_then_search PASSED
```

## Ingest the full HackTricks corpus

```sh
export HACKTRICKS_REPO_URL=<repo-url>
export HACKTRICKS_PATH=data/hacktricks
cd lib && uv run python -m lib.ingest
```

This clones HackTricks (~200 MB), chunks all markdown files, embeds them via Ollama, and writes to the `hacktricks` Qdrant collection. On a CPU-only machine this takes several hours for the full corpus; use `VECTOR_SIZE=768` (the default) with `nomic-embed-text`.

## Load the MCP server in your tool

The MCP server runs over stdio — no HTTP port. Wire it into your tool with:

```json
{
  "mcpServers": {
    "rag-search": {
      "command": "uv",
      "args": ["run", "--directory", "<absolute-path-to>/mcp", "python", "-m", "mcp_server"],
      "env": {
        "QDRANT_URL": "http://localhost:6333",
        "OLLAMA_URL": "http://localhost:11434"
      }
    }
  }
}
```

Tool-specific placement: `.mcp.json` for Claude Code; `opencode.json` under `mcpServers` for OpenCode; use your tool's equivalent for others.

## Run all unit and integration tests

```sh
cd lib && uv run pytest
cd mcp && uv run pytest
```

Run as separate commands — the two `tests/conftest.py` files collide when pytest is invoked from the workspace root.

## Tear down

```sh
docker compose down
```

Data in the `qdrant-data` volume persists; add `-v` to wipe it.

## What this proves

The full pipeline — chunker → embedder → store → search → MCP tool — is connected end-to-end with real services. If this smoke check passes, the build is correct in shape. Re-run `test_e2e.py` as a sanity check whenever a subsystem changes.
