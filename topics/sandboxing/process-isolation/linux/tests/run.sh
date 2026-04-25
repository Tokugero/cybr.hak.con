#!/usr/bin/env bash
# Test harness for process-isolation (Linux).
#
# Runs the cred-scrub probe in three configurations:
#   1. Host (baseline) — your real environment.
#   2. Permissive bwrap (--bind / /) — should look nearly identical to host.
#   3. Hardened bwrap (minimal binds, no home) — dotfiles unreachable.
#
# Asserts the diff. The hardened sandbox should clean every probe row
# that depends on home-dir contents.
#
# Skips cleanly if bwrap isn't available or user namespaces are disabled.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SANDBOXING_DIR="$(cd "$TOPIC_DIR/.." && pwd)"
PROBE="$SANDBOXING_DIR/cred-scrub/linux/probe.sh"

if ! command -v bwrap >/dev/null 2>&1; then
  echo "SKIP: bwrap not installed (apt/pacman/dnf install bubblewrap)"
  exit 0
fi

if ! unshare -U /bin/true 2>/dev/null; then
  echo "SKIP: user namespaces disabled on this kernel"
  exit 0
fi

HOST_OUT="$SCRIPT_DIR/.host.txt"
PERMISSIVE_OUT="$SCRIPT_DIR/.permissive.txt"
HARDENED_OUT="$SCRIPT_DIR/.hardened.txt"

echo "=== 1. Probe on host (baseline) ==="
bash "$PROBE" > "$HOST_OUT" 2>&1
cat "$HOST_OUT"
echo

echo "=== 2. Probe inside permissive bwrap ==="
bash "$TOPIC_DIR/bwrap-permissive.sh" > "$PERMISSIVE_OUT" 2>&1
cat "$PERMISSIVE_OUT"
echo

echo "=== 3. Probe inside hardened bwrap ==="
bash "$TOPIC_DIR/bwrap-hardened.sh" > "$HARDENED_OUT" 2>&1
cat "$HARDENED_OUT"
echo

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

assert_count_changed() {
  local desc="$1" status="$2" host_out="$3" hardened_out="$4"
  local host_count hardened_count
  host_count=$(grep -c " $status " "$host_out" 2>/dev/null || true)
  hardened_count=$(grep -c " $status " "$hardened_out" 2>/dev/null || true)
  if [ "$hardened_count" -lt "$host_count" ]; then
    echo "PASS: $desc (host $host_count, hardened $hardened_count)"
  else
    echo "FAIL: $desc (host $host_count, hardened $hardened_count — should have decreased)"
    fail=1
  fi
}

permissive_text=$(cat "$PERMISSIVE_OUT")
hardened_text=$(cat "$HARDENED_OUT")

# Hardened: home-dir dotfile rows should be clean (no .aws, .kube, .docker, etc.)
assert "hardened: AWS config clean (no home bind)"      "$hardened_text" "AWS config +\| clean"
assert "hardened: Kubeconfig clean"                     "$hardened_text" "Kubeconfig +\| clean"
assert "hardened: SSH agent clean (--unshare-net)"      "$hardened_text" "SSH agent +\| clean"
assert "hardened: SSH private keys clean"               "$hardened_text" "SSH private keys +\| clean"

# Permissive should NOT clean the dotfiles (because of --bind / /)
# Note: env vars depend on what's set when the test runs; checking dotfiles is sturdier.
# We compare counts: hardened should have fewer "present" rows than permissive.
assert_count_changed "hardened has fewer 'present' rows than permissive" \
  "present" "$PERMISSIVE_OUT" "$HARDENED_OUT"

if [ $fail -eq 0 ]; then
  echo
  echo "PASS: process-isolation behaviors as expected"
else
  echo
  echo "FAIL: at least one assertion did not match"
fi
exit $fail
