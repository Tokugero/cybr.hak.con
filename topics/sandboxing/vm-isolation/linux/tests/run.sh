#!/usr/bin/env bash
# Test harness for vm-isolation (Linux).
#
# Skips by default because running this is expensive: ~3 minutes on
# first run including the 600 MB image download, ~60-90 seconds on
# subsequent runs. To actually run the harness, set RUN_VM_HARNESS=1.
#
# When run, asserts:
#   - SSH became reachable (the boot worked)
#   - Cred-scrub probe inside VM shows AWS env vars clean (fresh env)
#   - Container-shape probe shows uid 1000, container detection: no
#   - Kernel inside differs from host kernel
#
# Skips cleanly if qemu, cloud-localds, or the required setup is
# unavailable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "${RUN_VM_HARNESS:-0}" != "1" ]; then
  echo "SKIP: VM harness is expensive (3 min first run, ~90s subsequent)."
  echo "      Set RUN_VM_HARNESS=1 to actually run it."
  echo "      Example:  RUN_VM_HARNESS=1 bash $0"
  exit 0
fi

# Dependency checks
for cmd in qemu-system-x86_64 qemu-img cloud-localds ssh scp ssh-keygen curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SKIP: $cmd not installed"
    exit 0
  fi
done

if [ ! -e /dev/kvm ]; then
  echo "WARN: /dev/kvm absent; this will use TCG software emulation (slow)"
fi

OUT="$SCRIPT_DIR/.vm-run.txt"

echo "=== Running launch-and-probe.sh (this will take ~60-180 seconds) ==="
bash "$TOPIC_DIR/launch-and-probe.sh" > "$OUT" 2>&1
launch_exit=$?
cat "$OUT"
echo

if [ $launch_exit -ne 0 ]; then
  echo "FAIL: launch-and-probe.sh exited $launch_exit"
  exit $launch_exit
fi

# ── Assertions ──
echo "=== assertions ==="
fail=0

assert() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qE "$needle"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    echo "       (expected: $needle)"
    fail=1
  fi
}

text=$(cat "$OUT")

# SSH reachable (negative — must NOT match the "never became reachable" error)
if echo "$text" | grep -q "SSH never became reachable"; then
  echo "FAIL: SSH never became reachable"
  fail=1
else
  echo "PASS: SSH became reachable"
fi

# Cred-scrub probe inside VM should show clean env vars
assert "VM: AWS env vars clean"     "$text" "AWS env vars +\| clean"
assert "VM: Git tokens clean"       "$text" "Git tokens +\| clean"
assert "VM: SSH agent clean"        "$text" "SSH agent +\| clean"

# Container-shape probe inside VM
assert "VM: uid 1000 (cloud-init agent user)" "$text" "uid +\| 1000"
assert "VM: NOT detected as container"        "$text" "container +\| no"

# Kernel comparison: should show two different release strings
host_kernel=$(uname -r)
if echo "$text" | grep -q "Guest kernel:" && \
   ! echo "$text" | grep -q "Guest kernel: $host_kernel"; then
  echo "PASS: Guest kernel differs from host kernel"
else
  echo "FAIL: Could not confirm kernel difference"
  fail=1
fi

if [ $fail -eq 0 ]; then
  echo
  echo "PASS: VM isolation behaviors as expected"
else
  echo
  echo "FAIL: at least one assertion did not match"
fi
exit $fail
