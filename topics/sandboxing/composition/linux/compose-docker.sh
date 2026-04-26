#!/usr/bin/env bash
# compose-docker.sh — Tier 0 + Tier 2 (hardened Docker) composition example.
#
# Demonstrates the portable middle of the spectrum: scrubbed host shell,
# then the cred-scrub probe + container shape probe inside a hardened
# Docker container. Heavier than bwrap (image pull, daemon, layer)
# but works the same on Mac and Windows.
#
# Assumes your host shell already has cred-scrub + direnv-perimeter
# applied. This script doesn't re-scrub on its own.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKER_RUNNER="$SANDBOXING_DIR/container-isolation/linux/run-hardened.sh"

if [ ! -x "$DOCKER_RUNNER" ]; then
  echo "ERROR: container-isolation runner not found at $DOCKER_RUNNER" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "ERROR: docker not reachable" >&2
  exit 127
fi

echo "=========================================================="
echo "Composition: Tier 0 (host shell hygiene) + Tier 2 (Docker hardened)"
echo "=========================================================="
echo
echo "Host shell environment (Tier 0 — should already be scrubbed):"
echo "  AWS_PROFILE: ${AWS_PROFILE:-unset}"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+(set)}${GITHUB_TOKEN:-unset}"
echo "  KUBECONFIG: ${KUBECONFIG:-unset}"
echo
echo "Now running cred-scrub + container-shape probes inside hardened Docker..."
echo

exec bash "$DOCKER_RUNNER"
