#!/usr/bin/env bash
# bwrap-permissive.sh — runs the cred-scrub probe inside a bwrap that
# binds the entire host filesystem and shares the network.
#
# This is the deliberately-weak example: bwrap with the wrong flags
# isolates almost nothing. The cred-scrub probe inside this sandbox
# should look nearly identical to the probe on the host. That's the
# point — the workshop wants you to see this failure mode.
#
# Pair with bwrap-hardened.sh to see the contrast.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROBE="$SANDBOXING_DIR/cred-scrub/linux/probe.sh"

if ! command -v bwrap >/dev/null 2>&1; then
  echo "ERROR: bwrap not found. Install bubblewrap (apt/pacman/dnf install bubblewrap)" >&2
  exit 127
fi

echo "Running cred-scrub probe inside a PERMISSIVE bwrap (--bind / /, network shared)"
echo

bwrap \
  --bind / / \
  --dev-bind /dev /dev \
  --proc /proc \
  --tmpfs /run \
  bash "$PROBE"
