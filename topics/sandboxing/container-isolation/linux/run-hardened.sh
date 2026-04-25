#!/usr/bin/env bash
# Launch a HARDENED Docker container with both probes mounted in.
#
# Hardening flags applied:
#   --user=$(id -u):$(id -g)         run as host user, not root
#   --network=none                   no network access at all
#   --read-only                      rootfs is read-only
#   --tmpfs /tmp                     give the container a writable /tmp
#   --cap-drop=ALL                   drop all Linux capabilities
#   --security-opt=no-new-privileges block setuid escalation
#
# This is the fair Tier 2 demo. The cred-scrub probe should still show
# nearly everything clean (same as default), and the container shape
# probe should show meaningful isolation in every dimension.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

echo "Launching HARDENED Docker container (ubuntu:24.04)"
echo "  uid: $HOST_UID, gid: $HOST_GID"
echo "  Mount: $SANDBOXING_DIR -> /workshop (read-only)"
echo "  Network: none"
echo "  Capabilities: ALL dropped"
echo "  Filesystem: read-only (tmpfs /tmp)"
echo "  no-new-privileges: enabled"
echo

docker run --rm \
  --user="$HOST_UID:$HOST_GID" \
  --network=none \
  --read-only \
  --tmpfs /tmp \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  -v "$SANDBOXING_DIR:/workshop:ro" \
  ubuntu:24.04 \
  bash -c '
    set -uo pipefail
    echo "=========================================================="
    echo "cred-scrub probe (inside HARDENED container)"
    echo "=========================================================="
    bash /workshop/cred-scrub/linux/probe.sh || true
    echo
    echo "=========================================================="
    echo "container shape probe (inside HARDENED container)"
    echo "=========================================================="
    bash /workshop/container-isolation/linux/container-probe.sh || true
  '
