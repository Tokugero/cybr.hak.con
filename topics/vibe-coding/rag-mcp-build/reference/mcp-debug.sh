#!/usr/bin/env bash
LOG=/tmp/mcp-debug.log
echo "=== $(date) ===" >> "$LOG"
echo "CWD: $(pwd)" >> "$LOG"
echo "USER: $(id)" >> "$LOG"
echo "ENV:" >> "$LOG"
env >> "$LOG"
echo "--- starting server ---" >> "$LOG"
exec /home/tokugero/.local/bin/uv run \
  --directory /home/tokugero/repos/github/tokugero/cybr.hak.con/topics/vibe-coding/rag-mcp-build \
  python -m mcp_server 2>>"$LOG"
