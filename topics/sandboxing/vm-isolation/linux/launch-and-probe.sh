#!/usr/bin/env bash
# launch-and-probe.sh — boots a fresh Ubuntu VM, runs the cred-scrub +
# container-shape probes inside it, shuts down.
#
# First run downloads ~600MB Ubuntu cloud image (cached at
# ~/.cache/cybr-hak-con-vm/). Subsequent runs reuse the cached image.
#
# Uses KVM acceleration if /dev/kvm is readable; falls back to TCG
# software emulation otherwise (much slower).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOXING_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

CACHE_DIR="$HOME/.cache/cybr-hak-con-vm"
mkdir -p "$CACHE_DIR"

IMAGE_URL="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
IMAGE_PATH="$CACHE_DIR/ubuntu-24.04-server-cloudimg-amd64.img"
DISK_PATH="$CACHE_DIR/disk.qcow2"
USERDATA_YAML="$CACHE_DIR/userdata.yaml"
USERDATA_ISO="$CACHE_DIR/userdata.iso"
SSH_KEY="$CACHE_DIR/ssh_key"
SSH_PUBKEY="$CACHE_DIR/ssh_key.pub"
PID_FILE="$CACHE_DIR/qemu.pid"
SSH_PORT=2222

# ── Dependency checks ──
require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' not found. $2" >&2
    exit 127
  fi
}
require qemu-system-x86_64 "Install qemu (apt install qemu-system-x86)"
require qemu-img "Install qemu-utils"
require cloud-localds "Install cloud-utils (apt install cloud-image-utils)"
require ssh "Install openssh-client"
require scp "Install openssh-client"
require ssh-keygen "Install openssh-client"
require curl "Install curl"

# ── Cleanup any previous run ──
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Killing previous VM (PID $OLD_PID)..."
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$OLD_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

# ── Download image if needed ──
if [ ! -f "$IMAGE_PATH" ]; then
  echo "Downloading Ubuntu 24.04 cloud image (~600MB, one-time)..."
  curl -fL --progress-bar "$IMAGE_URL" -o "$IMAGE_PATH.tmp"
  mv "$IMAGE_PATH.tmp" "$IMAGE_PATH"
  echo "Downloaded."
fi

# ── Generate SSH keypair if needed ──
if [ ! -f "$SSH_KEY" ]; then
  echo "Generating SSH keypair (cached for reuse)..."
  ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -q -C "cybr-hak-con-vm"
fi

# ── Generate cloud-init user-data ──
cat > "$USERDATA_YAML" <<EOF
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

cloud-localds "$USERDATA_ISO" "$USERDATA_YAML" >/dev/null 2>&1

# ── Create overlay disk ──
rm -f "$DISK_PATH"
qemu-img create -q -f qcow2 -F qcow2 -b "$IMAGE_PATH" "$DISK_PATH" 10G >/dev/null

# ── Determine KVM availability ──
KVM_ARGS=()
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  KVM_ARGS=(-enable-kvm -cpu host)
  echo "KVM available — using hardware acceleration."
else
  echo "KVM not available — falling back to TCG (slower; expect ~2-3 min boot)."
fi

# ── Boot the VM in the background ──
echo "Booting VM..."
qemu-system-x86_64 \
  "${KVM_ARGS[@]}" \
  -m 1G \
  -smp 2 \
  -drive file="$DISK_PATH",if=virtio \
  -drive file="$USERDATA_ISO",format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::"$SSH_PORT"-:22 \
  -device virtio-net,netdev=net0 \
  -nographic \
  -serial null \
  -monitor null \
  -display none \
  -daemonize \
  -pidfile "$PID_FILE"

# ── Wait for SSH ──
echo "Waiting for SSH (this can take 30-90 seconds on first boot)..."
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=2 -o LogLevel=ERROR
          -i "$SSH_KEY" -p "$SSH_PORT")

reachable=false
for i in $(seq 1 90); do
  if ssh "${SSH_OPTS[@]}" agent@localhost true 2>/dev/null; then
    reachable=true
    break
  fi
  sleep 2
done

if [ "$reachable" != true ]; then
  echo "ERROR: SSH never became reachable. Showing qemu PID and exiting."
  [ -f "$PID_FILE" ] && cat "$PID_FILE"
  exit 1
fi

echo "SSH reachable. Running probes inside the VM."
echo

# ── Copy probes in ──
scp "${SSH_OPTS[@]}" \
    "$SANDBOXING_DIR/cred-scrub/linux/probe.sh" \
    "$SANDBOXING_DIR/container-isolation/linux/container-probe.sh" \
    agent@localhost:/tmp/ >/dev/null

# ── Run probes ──
echo "=========================================================="
echo "cred-scrub probe inside the VM"
echo "=========================================================="
ssh "${SSH_OPTS[@]}" agent@localhost "bash /tmp/probe.sh"
echo

echo "=========================================================="
echo "container-shape probe inside the VM"
echo "=========================================================="
ssh "${SSH_OPTS[@]}" agent@localhost "bash /tmp/container-probe.sh"
echo

echo "=========================================================="
echo "Kernel comparison"
echo "=========================================================="
echo "Host kernel:  $(uname -r)"
echo "Guest kernel: $(ssh "${SSH_OPTS[@]}" agent@localhost uname -r)"
echo

# ── Shut down ──
echo "Shutting down VM..."
if [ -f "$PID_FILE" ]; then
  QEMU_PID=$(cat "$PID_FILE")
  # Try graceful shutdown first
  ssh "${SSH_OPTS[@]}" agent@localhost "sudo poweroff" 2>/dev/null || true
  # Wait briefly, then force-kill if still running
  for i in $(seq 1 8); do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  kill "$QEMU_PID" 2>/dev/null || true
  sleep 1
  kill -9 "$QEMU_PID" 2>/dev/null || true
  rm -f "$PID_FILE"
fi
echo "VM stopped."
