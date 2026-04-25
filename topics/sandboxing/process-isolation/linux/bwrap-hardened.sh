#!/usr/bin/env bash
# bwrap-hardened.sh — runs the cred-scrub probe inside a hardened bwrap.
#
# Binds only standard read-only system paths plus the workshop dir.
# HOME is set to a tmpfs-backed /tmp, so dotfile probes find nothing.
# Namespaces unshared: pid, uts, ipc, cgroup, net.
# (User namespace deliberately not unshared — keeps `id` predictable.)
#
# Optional extra args after `--` are passed through to the bwrap'd
# command. By default we run the cred-scrub probe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROBE="$SANDBOXING_DIR/cred-scrub/linux/probe.sh"

if ! command -v bwrap >/dev/null 2>&1; then
  echo "ERROR: bwrap not found. Install bubblewrap (apt/pacman/dnf install bubblewrap)" >&2
  exit 127
fi

# Build --ro-bind args for whatever standard system dirs exist
BIND_ARGS=()
for dir in /usr /lib /lib64 /bin /sbin /etc /nix/store /run/current-system; do
  if [ -e "$dir" ]; then
    BIND_ARGS+=(--ro-bind "$dir" "$dir")
  fi
done

echo "Running cred-scrub probe inside a HARDENED bwrap"
echo "  Bound (ro): system paths only + workshop"
echo "  Network:    isolated (--unshare-net)"
echo "  HOME:       /tmp (no real home dir)"
echo

bwrap \
  "${BIND_ARGS[@]}" \
  --ro-bind "$SANDBOXING_DIR" /workshop \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --tmpfs /run \
  --setenv HOME /tmp \
  --setenv USER "$USER" \
  --unshare-pid --unshare-uts --unshare-ipc --unshare-cgroup --unshare-net \
  --die-with-parent \
  --new-session \
  bash /workshop/cred-scrub/linux/probe.sh "$@"
