#!/usr/bin/env bash
# Test harness for the Linux cred-scrub.
#
# Seeds a fake HOME with known credentials, runs the probe to baseline,
# applies the scrubber, runs the probe again, and prints a pass/fail
# summary based on how many env-var categories survived.
#
# Doesn't touch your real HOME or environment — everything runs in a
# subshell with a temp HOME that's deleted on exit.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

(
  source "$SCRIPT_DIR/seed.sh"
  trap 'rm -rf "$HOME"' EXIT

  echo "=== baseline probe ==="
  bash "$TOPIC_DIR/probe.sh" > "$SCRIPT_DIR/.baseline.txt"
  cat "$SCRIPT_DIR/.baseline.txt"
  echo

  echo "=== applying scrubber ==="
  # log_status and dotenv_if_exists are direnv builtins; stub them so
  # solution.envrc can be sourced outside of a real direnv invocation.
  log_status() { echo "[scrubber] $*"; }
  dotenv_if_exists() { [ -f "${1:-.env}" ] && set -a && . "${1:-.env}" && set +a; return 0; }
  # shellcheck disable=SC1091
  source "$TOPIC_DIR/solution.envrc"
  echo

  echo "=== scrubbed probe ==="
  bash "$TOPIC_DIR/probe.sh" > "$SCRIPT_DIR/.scrubbed.txt"
  cat "$SCRIPT_DIR/.scrubbed.txt"
  echo

  count() { grep -c " $1 " "$2" 2>/dev/null || true; }

  baseline_exposed=$(count exposed "$SCRIPT_DIR/.baseline.txt")
  scrubbed_exposed=$(count exposed "$SCRIPT_DIR/.scrubbed.txt")
  baseline_present=$(count present "$SCRIPT_DIR/.baseline.txt")
  scrubbed_present=$(count present "$SCRIPT_DIR/.scrubbed.txt")
  baseline_active=$(count active  "$SCRIPT_DIR/.baseline.txt")
  scrubbed_active=$(count active  "$SCRIPT_DIR/.scrubbed.txt")
  baseline_default=$(count default "$SCRIPT_DIR/.baseline.txt")
  scrubbed_default=$(count default "$SCRIPT_DIR/.scrubbed.txt")
  baseline_redirected=$(count redirected "$SCRIPT_DIR/.baseline.txt")
  scrubbed_redirected=$(count redirected "$SCRIPT_DIR/.scrubbed.txt")

  echo "=== summary ==="
  printf '%-26s | %-8s | %-8s\n' "Status" "baseline" "scrubbed"
  printf -- '---------------------------+----------+---------\n'
  printf '%-26s | %8d | %8d\n' "exposed (env vars)"          "$baseline_exposed"    "$scrubbed_exposed"
  printf '%-26s | %8d | %8d\n' "present (dotfiles)"          "$baseline_present"    "$scrubbed_present"
  printf '%-26s | %8d | %8d\n' "active (agents)"             "$baseline_active"     "$scrubbed_active"
  printf '%-26s | %8d | %8d\n' "default (paths reachable)"   "$baseline_default"    "$scrubbed_default"
  printf '%-26s | %8d | %8d\n' "redirected (paths blocked)"  "$baseline_redirected" "$scrubbed_redirected"
  echo

  fail=0
  if [ "$scrubbed_exposed" -gt 0 ]; then
    echo "FAIL: $scrubbed_exposed exposed env-var categories survived:"
    grep " exposed " "$SCRIPT_DIR/.scrubbed.txt"
    fail=1
  fi
  if [ "$scrubbed_default" -gt 0 ]; then
    echo "FAIL: $scrubbed_default config paths still fall back to disk defaults:"
    grep " default " "$SCRIPT_DIR/.scrubbed.txt"
    fail=1
  fi
  if [ "$fail" -eq 0 ]; then
    echo "PASS: env vars cleaned and config paths redirected"
  fi
  exit "$fail"
)
