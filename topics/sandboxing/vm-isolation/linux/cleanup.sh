#!/usr/bin/env bash
# cleanup.sh — tear down any running VM and remove the cached overlay disk.
#
# Doesn't remove the cached base image (~600MB) by default since
# that's a big one-time download. Pass --full to remove everything
# including the base image.

set -euo pipefail

CACHE_DIR="$HOME/.cache/cybr-hak-con-vm"
PID_FILE="$CACHE_DIR/qemu.pid"
DISK_PATH="$CACHE_DIR/disk.qcow2"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "Killing VM (PID $PID)..."
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

if [ -f "$DISK_PATH" ]; then
  rm -f "$DISK_PATH"
  echo "Removed overlay disk: $DISK_PATH"
fi

if [ "${1:-}" = "--full" ]; then
  rm -rf "$CACHE_DIR"
  echo "Removed entire cache: $CACHE_DIR"
fi

echo "Done."
