#!/usr/bin/env bash
# Test harness for network-egress (Linux).
#
# Runs the egress probe in two configurations:
#   1. Default container, no sidecar (baseline) — should reach the internet.
#   2. Worker container sharing gluetun's namespace, NO VPN credentials —
#      should fail closed (no DNS, no HTTPS, no raw TCP egress).
#
# Asserts the diff. The fail-closed behavior is the whole lesson; if
# the sidecar run shows internet reachability without VPN credentials,
# the gluetun firewall isn't doing its job and the workshop misses
# its main point.
#
# Skips cleanly if Docker or docker-compose v2 is unavailable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable"
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: docker compose v2 not available"
  exit 0
fi

BASELINE_OUT="$SCRIPT_DIR/.baseline.txt"
SIDECAR_OUT="$SCRIPT_DIR/.sidecar.txt"

echo "=== Pulling required images ==="
docker pull -q ubuntu:24.04 >/dev/null 2>&1 || true
docker pull -q qmcgaw/gluetun:v3 >/dev/null 2>&1 || true

echo "=== Building workshop image ==="
docker build -q -t cybr-hak-con-egress:latest "$TOPIC_DIR" >/dev/null
echo "  built"
echo

echo "=== Running BASELINE (default container, no sidecar) ==="
bash "$TOPIC_DIR/run-baseline.sh" > "$BASELINE_OUT" 2>&1
cat "$BASELINE_OUT"
echo

# Make sure no stale stack is hanging around before sidecar run
docker compose -f "$TOPIC_DIR/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true

echo "=== Running VIA SIDECAR (no VPN credentials, fail-closed) ==="
bash "$TOPIC_DIR/run-via-sidecar.sh" > "$SIDECAR_OUT" 2>&1
cat "$SIDECAR_OUT"
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

baseline_text=$(cat "$BASELINE_OUT")
sidecar_text=$(cat "$SIDECAR_OUT")

# Baseline: default container reaches the internet
assert "baseline: DNS reachable"         "$baseline_text" "DNS: example.com +\| reachable"
assert "baseline: HTTPS reachable"       "$baseline_text" "HTTPS: example.com +\| reachable"
assert "baseline: raw TCP reachable"     "$baseline_text" "TCP 22 \(raw\): github +\| reachable"

# Sidecar (no VPN creds): everything fails closed
assert "sidecar: DNS fail (no VPN)"      "$sidecar_text"  "DNS: example.com +\| fail"
assert "sidecar: HTTPS fail (no VPN)"    "$sidecar_text"  "HTTPS: example.com +\| fail"
assert "sidecar: direct IP fail"         "$sidecar_text"  "HTTPS: 1.1.1.1 direct +\| fail"
assert "sidecar: exit IP fail"           "$sidecar_text"  "Exit IP +\| fail"
assert "sidecar: raw TCP fail"           "$sidecar_text"  "TCP 22 \(raw\): github +\| fail"

if [ $fail -eq 0 ]; then
  echo
  echo "PASS: network-egress fail-closed behavior verified"
else
  echo
  echo "FAIL: at least one assertion did not match"
fi
exit $fail
