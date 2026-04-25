#!/usr/bin/env bash
# Run the egress probe in a default Docker container — no sidecar,
# default network bridge, full host-equivalent egress via NAT.
#
# This is the baseline for comparison against run-via-sidecar.sh. The
# default container should reach the internet identically to your
# host. The sidecar variant should fail-closed without VPN credentials.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Build the workshop image if not already present
if ! docker image inspect cybr-hak-con-egress:latest >/dev/null 2>&1; then
  echo "Building cybr-hak-con-egress image (one-time, ~30s)..."
  docker build -q -t cybr-hak-con-egress:latest "$SCRIPT_DIR" >/dev/null
  echo "Built."
fi

echo "Running egress-probe in DEFAULT container (no VPN sidecar)..."
echo

docker run --rm \
  -v "$SANDBOXING_DIR:/workshop:ro" \
  cybr-hak-con-egress:latest \
  bash /workshop/network-egress/linux/egress-probe.sh
