#!/usr/bin/env bash
# compose-docker-egress.sh — Tier 0 + Tier 2 + network-egress sidecar.
#
# Demonstrates the strongest first-pass composition: scrubbed host
# shell, hardened Docker container, plus a gluetun sidecar that owns
# the worker's network namespace. Without VPN credentials, network is
# fail-closed; with them, traffic exits via the VPN.
#
# Assumes your host shell already has cred-scrub + direnv-perimeter
# applied. This script doesn't re-scrub on its own.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
EGRESS_RUNNER="$SANDBOXING_DIR/network-egress/linux/run-via-sidecar.sh"

if [ ! -x "$EGRESS_RUNNER" ]; then
  echo "ERROR: network-egress runner not found at $EGRESS_RUNNER" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "ERROR: docker not reachable" >&2
  exit 127
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose v2 not available" >&2
  exit 127
fi

echo "=========================================================="
echo "Composition: Tier 0 + Tier 2 (Docker) + network-egress sidecar"
echo "=========================================================="
echo
echo "Host shell environment (Tier 0 — should already be scrubbed):"
echo "  AWS_PROFILE: ${AWS_PROFILE:-unset}"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+(set)}${GITHUB_TOKEN:-unset}"
echo "  KUBECONFIG: ${KUBECONFIG:-unset}"
echo
echo "Bringing up gluetun + worker stack and running the egress probe..."
echo

# The network-egress run-via-sidecar.sh script handles the compose stack
# lifecycle: brings up gluetun + worker, runs the egress probe inside
# the worker, tears down. With no VPN credentials in .env, the worker
# is fail-closed — egress probe shows everything fails.
exec bash "$EGRESS_RUNNER"
