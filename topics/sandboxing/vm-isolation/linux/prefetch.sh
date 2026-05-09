#!/usr/bin/env bash
# prefetch.sh — Run this the night before, on good wifi.
#
# Downloads the Debian 12 generic-cloud image (~350 MB), generates the
# SSH keypair, and builds the cloud-init seed ISO into the same cache
# directory `launch-and-probe.sh` reads from. Idempotent — safe to
# re-run; existing artifacts are kept.
#
# After this completes, `launch-and-probe.sh` boots in seconds (no
# download, no network needed). This separates the "slow part that needs
# the network" from "the part you do at the workshop."

set -euo pipefail

CACHE_DIR="$HOME/.cache/cybr-hak-con-vm"
mkdir -p "$CACHE_DIR"

IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
IMAGE_PATH="$CACHE_DIR/debian-12-genericcloud-amd64.qcow2"
USERDATA_YAML="$CACHE_DIR/userdata.yaml"
USERDATA_ISO="$CACHE_DIR/userdata.iso"
SSH_KEY="$CACHE_DIR/ssh_key"
SSH_PUBKEY="$CACHE_DIR/ssh_key.pub"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' not found. $2" >&2
    exit 127
  fi
}
require curl "Install curl"
require ssh-keygen "Install openssh-client"
require cloud-localds "Install cloud-utils (Debian/Ubuntu: apt install cloud-image-utils; Arch: pacman -S cloud-image-utils; NixOS: wrap this script with 'nix-shell -p cloud-utils --run \"bash $0\"')"

# ── Image ──
if [ -f "$IMAGE_PATH" ]; then
  size_mb=$(( $(stat -c%s "$IMAGE_PATH" 2>/dev/null || stat -f%z "$IMAGE_PATH") / 1024 / 1024 ))
  echo "[skip] image already cached ($size_mb MB) at $IMAGE_PATH"
else
  echo "[fetch] Debian 12 generic-cloud image (~350 MB) -> $IMAGE_PATH"
  curl -fL --progress-bar "$IMAGE_URL" -o "$IMAGE_PATH.tmp"
  mv "$IMAGE_PATH.tmp" "$IMAGE_PATH"
fi

# ── SSH key ──
if [ -f "$SSH_KEY" ] && [ -f "$SSH_PUBKEY" ]; then
  echo "[skip] SSH keypair already present"
else
  echo "[gen]  SSH keypair (ed25519, no passphrase, workshop-scoped)"
  ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -q -C "cybr-hak-con-vm"
fi

# ── Cloud-init seed ──
# Render the userdata YAML to a temp file; only replace the cached copy if the
# content actually changed (e.g. the SSH pubkey rotated). Keeping the cached
# YAML's mtime stable lets the ISO timestamp check below short-circuit on warm
# re-runs.
NEW_YAML="$(mktemp)"
trap 'rm -f "$NEW_YAML"' EXIT
cat > "$NEW_YAML" <<EOF
#cloud-config
users:
  - name: agent
    ssh_authorized_keys:
      - $(cat "$SSH_PUBKEY")
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash

# Disable apt updates at boot to keep boot time down for the workshop
package_update: false
package_upgrade: false

# Disable cloud-init's first-boot wait that delays SSH availability
runcmd:
  - [ systemctl, restart, ssh ]
EOF

if [ -f "$USERDATA_YAML" ] && cmp -s "$NEW_YAML" "$USERDATA_YAML"; then
  echo "[skip] cloud-init userdata unchanged"
else
  echo "[gen]  cloud-init userdata -> $USERDATA_YAML"
  mv "$NEW_YAML" "$USERDATA_YAML"
fi

if [ -f "$USERDATA_ISO" ] && [ "$USERDATA_ISO" -nt "$USERDATA_YAML" ]; then
  echo "[skip] cloud-init seed ISO up to date"
else
  echo "[build] cloud-init seed ISO -> $USERDATA_ISO"
  cloud-localds "$USERDATA_ISO" "$USERDATA_YAML" >/dev/null 2>&1
fi

echo
echo "Prefetch complete. Cache:"
ls -lh "$CACHE_DIR" 2>/dev/null | awk 'NR>1 {printf "  %-10s %s\n", $5, $NF}'
echo
echo "You can now run launch-and-probe.sh offline (no further downloads needed)."
