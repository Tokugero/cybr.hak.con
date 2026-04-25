#!/usr/bin/env bash
# Test harness for container-isolation (Linux).
#
# Runs both the default and hardened containers, captures probe output,
# asserts that the hardened container's posture is meaningfully tighter
# on every dimension we care about: uid, capabilities, root filesystem,
# network namespace, /tmp.
#
# Skips cleanly if Docker isn't reachable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker command not found"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable (run 'docker info' to debug)"
  exit 0
fi

DEFAULT_OUT="$SCRIPT_DIR/.default.txt"
HARDENED_OUT="$SCRIPT_DIR/.hardened.txt"

echo "=== Pulling ubuntu:24.04 if needed ==="
docker pull ubuntu:24.04 >/dev/null 2>&1 || true
echo

echo "=== Running default container ==="
bash "$TOPIC_DIR/run-default.sh" > "$DEFAULT_OUT" 2>&1
cat "$DEFAULT_OUT"
echo

echo "=== Running hardened container ==="
bash "$TOPIC_DIR/run-hardened.sh" > "$HARDENED_OUT" 2>&1
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
    echo "       (expected to match: $needle)"
    fail=1
  fi
}

default_text=$(cat "$DEFAULT_OUT")
hardened_text=$(cat "$HARDENED_OUT")
my_uid=$(id -u)

# Default: uid 0 (Docker's default)
assert "default: uid 0 (root in container)" "$default_text" "uid +\| 0 +\|"

# Hardened: uid matches host user
assert "hardened: uid $my_uid (host user)"  "$hardened_text" "uid +\| $my_uid +\|"

# Default: container detected
assert "default: container detected"        "$default_text"  "container +\| (yes|likely)"

# Hardened: container detected (still in a container; just a hardened one)
assert "hardened: container detected"       "$hardened_text" "container +\| (yes|likely)"

# Default: capabilities non-zero (Docker grants a default set)
assert "default: capabilities non-zero"     "$default_text"  "Capabilities +\| non-zero"

# Hardened: capabilities all dropped
assert "hardened: capabilities all dropped" "$hardened_text" "Capabilities +\| all dropped"

# Default: rootfs writable
assert "default: rootfs writable"           "$default_text"  "Root filesystem +\| writable"

# Hardened: rootfs read-only
assert "hardened: rootfs read-only"         "$hardened_text" "Root filesystem +\| read-only"

# Default: network namespace active (Docker bridge)
assert "default: network namespace active"  "$default_text"  "Network namespace +\| active"

# Hardened: network isolated
assert "hardened: network isolated"         "$hardened_text" "Network namespace +\| isolated"

# Default: /tmp writable
assert "default: /tmp writable"             "$default_text"  "/tmp +\| writable"

# Hardened: /tmp writable (we mount tmpfs)
assert "hardened: /tmp writable (tmpfs)"    "$hardened_text" "/tmp +\| writable"

# Hardened: docker socket should be absent (we never mount it)
assert "hardened: docker socket absent"     "$hardened_text" "Docker socket +\| absent"

# Cred-scrub probe inside hardened: most env vars clean (no host env passed in)
assert "hardened cred-scrub: AWS env vars clean"  "$hardened_text" "AWS env vars +\| clean"
assert "hardened cred-scrub: Git tokens clean"    "$hardened_text" "Git tokens +\| clean"
assert "hardened cred-scrub: SSH agent clean"     "$hardened_text" "SSH agent +\| clean"

echo
if [ $fail -eq 0 ]; then
  echo "PASS: container behaviors as expected"
else
  echo "FAIL: at least one assertion did not match"
fi
exit $fail
