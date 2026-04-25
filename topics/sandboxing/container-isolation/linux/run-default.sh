#!/usr/bin/env bash
# Launch a DEFAULT Docker container with both probes mounted in.
#
# All Docker defaults: root inside the container, full default capabilities,
# default network bridge (so the container can reach the internet),
# writable rootfs.
#
# This is the "shell with a different home directory" version. It shows
# what credentials are no longer reachable (the cred-scrub probe will
# show most rows clean) and what the container's shape looks like with
# nothing hardened.

set -euo pipefail

# Find the sandboxing/ dir so we can mount it into the container and
# both probes can reach the cred-scrub probe via /workshop.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Launching DEFAULT Docker container (ubuntu:24.04)"
echo "  Mount: $SANDBOXING_DIR -> /workshop (read-only)"
echo "  No hardening flags (root, default caps, default network, writable rootfs)"
echo

docker run --rm \
  -v "$SANDBOXING_DIR:/workshop:ro" \
  ubuntu:24.04 \
  bash -c '
    set -uo pipefail
    echo "=========================================================="
    echo "cred-scrub probe (inside DEFAULT container)"
    echo "=========================================================="
    bash /workshop/cred-scrub/linux/probe.sh || true
    echo
    echo "=========================================================="
    echo "container shape probe (inside DEFAULT container)"
    echo "=========================================================="
    bash /workshop/container-isolation/linux/container-probe.sh || true
  '
