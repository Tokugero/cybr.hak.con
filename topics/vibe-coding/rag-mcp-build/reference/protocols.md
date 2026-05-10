# protocols.md — rag-mcp-build

Operational protocols for any agent working in this repository.

## Secrets
- **Never inline a secret value in a shell command.** Read from disk at runtime.
- `.env` for operational config (passwords, DSNs, API keys). Gitignored.
- `secrets/<name>` for standalone credential files. Gitignored.
- Missing secret: if safe to generate (e.g. a random token), generate, write, tell the human. If it must come from the human, stop and ask.

## Code style
- Python 3.13
- 2-space indentation, no tabs
- Specific dependency versions in `pyproject.toml` — never floating/latest
- Package manager: uv

## Permission gates — always ask before
1. Writing or modifying any secret or credential file.
2. Applying changes to a production system.
3. Running destructive commands (delete, drop, reset, purge).
4. Any action affecting more than one node/instance simultaneously.
5. Deleting git history or running `git push --force`.

Each gate requires a fresh ask, even if a similar action was approved earlier in the session.

## Dev shell
- Python environment managed by `uv`
- Run `uv sync` to install dependencies
- Local services (Qdrant + Ollama) started with `docker compose up -d`
- Ingestion is a one-time setup: `uv run python -m lib.ingest`
