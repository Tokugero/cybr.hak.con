# Workshop: rag-mcp-build

Build a Retrieval-Augmented Generation tool that ingests the [HackTricks](https://github.com/HackTricks-wiki/hacktricks) repository and exposes search via a Model Context Protocol server. The deliverable is a working tool you can point your AI agent at to look up security techniques without making it re-read the entire HackTricks site.

The goal isn't the tool — it's the four patterns the build exercises along the way. Layered docs the agent owns; a validation loop you can trust; testing shapes that signal real bugs; a parallel-buildable layout where two role agents (one for the library, one for the API) don't step on each other.

## What you build

- **A Python library** that fetches HackTricks, chunks it, embeds it locally with [Ollama](https://ollama.com/) and `nomic-embed-text` running CPU-only, and stores embeddings in [Qdrant](https://qdrant.tech/).
- **An API server** wrapping the library, exposing both an HTTP endpoint and an MCP server.
- **A docker-compose setup** that brings up Qdrant + the API; Ollama runs separately (locally on CPU, or on whatever endpoint you have).
- **An end-to-end harness** that proves search returns sensible results for a handful of canonical queries.

## What you exercise (per pattern)

| Pattern | Where in the workshop |
|---------|----------------------|
| Layered context documents | Step 01 (`.abstract.md`), step 02 (`.overview.md`), step 03 (per-subsystem layered docs); steps 04–06 keep them current as the code changes |
| Validation tools and steps | Step 03 sets up `protocols.md` with permission gates; step 04 wires test commands; step 05 makes tests the validation gate for every implementation step |
| Testing shapes and purpose | Step 04 lays out test directories at subsystem boundaries; step 05 uses behaviour-first design (confirm interface → confirm behaviours → red → green → refactor); step 06 adds end-to-end |
| Positioning to build in parallel | Step 03 creates two role agents (library + API) and an SRE agent; step 05 is the only step where role agents do parallel work; step 06 has the SRE agent do cross-subsystem validation |

## Prerequisites

- **Python 3.13+** with `uv` for dependency management
- **Docker** with Compose v2
- **Ollama** somewhere reachable (run locally on CPU, on a separate machine, or anywhere on your network) with the `nomic-embed-text` model pulled (`ollama pull nomic-embed-text`)
- **An LLM agent tool** — Claude Code, OpenCode, Cursor, Codex, Aider, or similar
- About 4 GB free disk for the HackTricks clone, embeddings, and Qdrant data
- About 60–90 minutes if you stay on the rails; longer if you take side quests (which are encouraged)

## Format — prompt-driven, tool-agnostic

The workshop lives entirely in `prompts/`. Each prompt is a markdown file with two voices:

- **What this step accomplishes (read this yourself)** — context for you, the participant. Skim it before invoking.
- **Instructions for the assistant (paste this part to your assistant)** — what your LLM should do. Hand it directly; the assistant follows it and stops at the end of the step.

You don't write code by hand. You direct; the assistant authors. The layered docs the assistant creates in step 01 establish that ownership pattern, and it carries through every later step.

You also don't run prompts in your AI tool's "auto" or "yolo" mode. Each prompt expects the assistant to ask questions, propose, and pause for your approval at decision points. That's the validation pattern — you're not absent from the loop, you're moved from author to director.

## The prompts

| # | Prompt | What it produces |
|---|--------|------------------|
| 01 | [`project-description`](prompts/01-project-description.md) | `.abstract.md` at the project root; ownership pattern declared between you and the assistant |
| 02 | `output-and-interface` | Root `.overview.md` with subsystem list, stack, endpoints |
| 03 | `skeleton-docs-and-gates` | `AGENTS.md`, `protocols.md`, `kb/README.md`, `docs/sre-todos.md`, role descriptions for two role agents and an SRE agent, per-subsystem `.abstract.md` and `.overview.md` stubs, `.envrc` |
| 04 | `tests-and-test-structure` | Test directories per subsystem, test commands wired into the relevant agent file, initial fixtures |
| 05a | `skeleton-and-interface` | Source skeleton with empty modules and the interface contracts the tests will exercise; first `.overview.md` Exports column populated |
| 05b | `first-red-green` | First failing test for the most important behaviour; minimum implementation to pass |
| 05c | `iterate` | Re-invokable prompt: each invocation runs another red-green cycle for the next behaviour |
| 06 | `end-to-end-and-walkthroughs` | docker-compose setup, end-to-end harness, walkthrough doc; SRE agent invoked for cross-subsystem validation |

After 06, the workshop has a follow-up section at the bottom of the README on **wiring the MCP server into your assistant** — a tool-specific final step (Claude Code: `.mcp.json`; OpenCode: `opencode.json`; Cursor / Codex / other: direct HTTP).

## When you're stuck

- The `reference/` directory contains a finished version of this build for comparison after you've done it yourself. Don't peek before — the workshop's value is the building.
- If a prompt seems wrong on your project (different scope, different language preference), tell your assistant *what* you'd change and *why*. The assistant should help you adapt the prompt while preserving the pattern it's exercising.

## Tool-specific final step — wiring the MCP server

Once step 06 is complete, you have a working MCP server. The way you connect your AI tool to it is tool-specific:

- **Claude Code:** Add the server to `.mcp.json` (stdio for local execution, http for the docker-compose setup):
  ```json
  {
    "mcpServers": {
      "hacktionary": {
        "type": "http",
        "url": "http://localhost:8000/mcp/"
      }
    }
  }
  ```
- **OpenCode:** Same MCP config goes into `opencode.json` under `mcpServers`.
- **Cursor / Codex / other:** Whatever your tool's MCP integration looks like (some tools don't have one yet). Direct HTTP works as a fallback — the server's OpenAPI spec is at `http://localhost:8000/docs` and the search endpoint at `http://localhost:8000/search`.
