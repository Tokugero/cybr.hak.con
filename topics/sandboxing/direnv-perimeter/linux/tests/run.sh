#!/usr/bin/env bash
# Test harness for direnv-perimeter (Linux).
#
# Verifies the fingerprint script reports the right thing in three states:
#   1. No perimeter (baseline) — fingerprint shows DIRENV_DIR unset.
#   2. Sample perimeter loaded — sentinels and scoped values present.
#   3. Nested perimeter loaded — child overrides parent, parent inherits.
#
# Doesn't touch your real $HOME or shell.
#
# Uses `direnv exec` instead of relying on the shell hook (the hook is
# interactive-only, and this script runs non-interactively).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build a temp dir tree mirroring the workshop's expected layout
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/perimeter-test-XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

cp "$TOPIC_DIR/sample.envrc" "$TEST_ROOT/.envrc"
mkdir -p "$TEST_ROOT/nested"
cp "$TOPIC_DIR/nested/sample.envrc" "$TEST_ROOT/nested/.envrc"

# Allow both .envrc files (idempotent; succeeds whether already allowed or not)
direnv allow "$TEST_ROOT" 2>/dev/null
direnv allow "$TEST_ROOT/nested" 2>/dev/null

run_fingerprint() {
  local dir="$1"
  (cd "$dir" && direnv exec . bash "$TOPIC_DIR/fingerprint.sh")
}

run_fingerprint_no_perimeter() {
  # Run from outside any allowed perimeter (the test root's parent has none)
  (cd / && bash "$TOPIC_DIR/fingerprint.sh")
}

# Capture outputs
echo "=== 1. fingerprint outside any perimeter ==="
baseline_out=$(run_fingerprint_no_perimeter)
echo "$baseline_out"
echo

echo "=== 2. fingerprint inside the parent perimeter ==="
parent_out=$(run_fingerprint "$TEST_ROOT")
echo "$parent_out"
echo

echo "=== 3. fingerprint inside the nested perimeter ==="
nested_out=$(run_fingerprint "$TEST_ROOT/nested")
echo "$nested_out"
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

# Baseline shouldn't have DIRENV_DIR or sentinels
assert "baseline: DIRENV_DIR unset"           "$baseline_out" "DIRENV_DIR +\| unset"
assert "baseline: PERIMETER_ACTIVE unset"     "$baseline_out" "PERIMETER_ACTIVE +\| unset"

# Parent perimeter should set sentinels and scoped values
assert "parent: DIRENV_DIR set"               "$parent_out"   "DIRENV_DIR +\| set"
assert "parent: PERIMETER_ACTIVE=yes"         "$parent_out"   "PERIMETER_ACTIVE +\| set +\| yes"
assert "parent: PERIMETER_NAME=sample"        "$parent_out"   "PERIMETER_NAME +\| set +\| sample"
assert "parent: AWS_PROFILE=engagement-test"  "$parent_out"   "AWS_PROFILE +\| set +\| engagement-test"
assert "parent: AWS_REGION=us-east-2"         "$parent_out"   "AWS_REGION +\| set +\| us-east-2"

# Nested perimeter should override name and region but inherit ACTIVE
assert "nested: PERIMETER_ACTIVE=yes (inherited)"   "$nested_out" "PERIMETER_ACTIVE +\| set +\| yes"
assert "nested: PERIMETER_NAME=nested (override)"   "$nested_out" "PERIMETER_NAME +\| set +\| nested"
assert "nested: AWS_REGION=eu-west-1 (override)"    "$nested_out" "AWS_REGION +\| set +\| eu-west-1"
assert "nested: AWS_PROFILE=engagement-test (inherited)" "$nested_out" "AWS_PROFILE +\| set +\| engagement-test"

echo
if [ "$fail" -eq 0 ]; then
  echo "PASS: perimeter behaviors as expected"
else
  echo "FAIL: at least one assertion did not match"
fi
exit "$fail"
