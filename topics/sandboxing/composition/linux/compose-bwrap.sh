#!/usr/bin/env bash
# compose-bwrap.sh — Tier 0 + Tier 1 (bubblewrap) composition example.
#
# Demonstrates the lightest end of the composition spectrum: scrubbed
# host shell, then the cred-scrub probe wrapped in a hardened bwrap.
# No daemon, no image. Linux-only.
#
# Assumes your host shell already has cred-scrub + direnv-perimeter
# applied (you launched it from inside a perimeter directory, or you
# used `direnv exec . bash compose-bwrap.sh`). This script doesn't
# re-scrub on its own; that's the host shell's job.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BWRAP_RUNNER="$SANDBOXING_DIR/process-isolation/linux/bwrap-hardened.sh"

if [ ! -x "$BWRAP_RUNNER" ]; then
  echo "ERROR: process-isolation runner not found at $BWRAP_RUNNER" >&2
  echo "       (this composition reuses the process-isolation topic's hardened bwrap)" >&2
  exit 1
fi

if ! command -v bwrap >/dev/null 2>&1; then
  echo "ERROR: bwrap not installed (apt/pacman/dnf install bubblewrap)" >&2
  exit 127
fi

echo "=========================================================="
echo "Composition: Tier 0 (host shell hygiene) + Tier 1 (bwrap)"
echo "=========================================================="
echo
echo "Host shell environment (Tier 0 — should already be scrubbed):"
echo "  AWS_PROFILE: ${AWS_PROFILE:-unset}"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+(set)}${GITHUB_TOKEN:-unset}"
echo "  KUBECONFIG: ${KUBECONFIG:-unset}"
echo
echo "Now running the cred-scrub probe inside the hardened bwrap..."
echo

# The bwrap-hardened.sh runner already mounts the workshop dir, sets
# HOME to a tmpfs, and unshares pid/uts/ipc/cgroup/net.
exec bash "$BWRAP_RUNNER"
