#!/usr/bin/env bash
# Test harness for composition (Linux).
#
# Verifies each of the three example runners produces sensible output
# by delegating to the underlying topic's harness or by running the
# runner and grepping for expected probe rows.
#
# Skips individual sub-tests if their dependencies aren't available.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

fail=0
sub_tests_run=0
sub_tests_skipped=0

# ── 1. compose-bwrap composition ──
echo "=== Sub-test 1: compose-bwrap ==="
if ! command -v bwrap >/dev/null 2>&1; then
  echo "SKIP: bwrap not installed"
  sub_tests_skipped=$((sub_tests_skipped + 1))
elif ! unshare -U /bin/true 2>/dev/null; then
  echo "SKIP: user namespaces disabled"
  sub_tests_skipped=$((sub_tests_skipped + 1))
else
  out=$(bash "$TOPIC_DIR/compose-bwrap.sh" 2>&1)
  if echo "$out" | grep -qE "AWS config +\| clean"; then
    echo "PASS: compose-bwrap shows AWS config clean (Tier 1 isolation)"
    sub_tests_run=$((sub_tests_run + 1))
  else
    echo "FAIL: compose-bwrap did not show AWS config as clean"
    fail=1
  fi
fi
echo

# ── 2. compose-docker composition ──
echo "=== Sub-test 2: compose-docker ==="
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not reachable"
  sub_tests_skipped=$((sub_tests_skipped + 1))
else
  out=$(bash "$TOPIC_DIR/compose-docker.sh" 2>&1)
  if echo "$out" | grep -qE "Capabilities +\| all dropped" && \
     echo "$out" | grep -qE "Network namespace +\| isolated"; then
    echo "PASS: compose-docker shows hardened container shape"
    sub_tests_run=$((sub_tests_run + 1))
  else
    echo "FAIL: compose-docker did not show hardened container shape"
    fail=1
  fi
fi
echo

# ── 3. compose-docker-egress composition ──
echo "=== Sub-test 3: compose-docker-egress ==="
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not reachable"
  sub_tests_skipped=$((sub_tests_skipped + 1))
elif ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: docker compose v2 not available"
  sub_tests_skipped=$((sub_tests_skipped + 1))
else
  out=$(bash "$TOPIC_DIR/compose-docker-egress.sh" 2>&1)
  if echo "$out" | grep -qE "DNS: example.com +\| fail" && \
     echo "$out" | grep -qE "HTTPS: example.com +\| fail"; then
    echo "PASS: compose-docker-egress shows fail-closed network (no VPN credentials)"
    sub_tests_run=$((sub_tests_run + 1))
  else
    echo "FAIL: compose-docker-egress did not show fail-closed network"
    fail=1
  fi
fi
echo

# ── Summary ──
echo "=== summary ==="
echo "Sub-tests run:     $sub_tests_run"
echo "Sub-tests skipped: $sub_tests_skipped"
if [ $fail -eq 0 ]; then
  if [ $sub_tests_run -eq 0 ]; then
    echo "INCONCLUSIVE: no compositions runnable on this host (all sub-tests skipped)"
    exit 0
  fi
  echo "PASS: all runnable compositions produced expected output"
else
  echo "FAIL: at least one composition's output didn't match expectations"
fi
exit $fail
