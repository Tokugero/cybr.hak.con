#!/usr/bin/env bash
# fingerprint.sh — does this shell sit inside a direnv perimeter?
# What does that perimeter set up?
#
# Read-only. Reports:
#   - DIRENV_DIR (direnv's own marker for "I've loaded an .envrc here")
#   - Sentinel env vars set by sample.envrc
#   - A few common scoped-credential env vars and their values
#   - Whether an .envrc file exists in $PWD
#
# Output format: three columns separated by " | ".
#   Indicator               | Status   | Value
#
# Status values:
#   set    — env var is non-empty
#   unset  — env var is missing or empty
#   yes/no — boolean indicators (.envrc presence)

set -uo pipefail
LC_ALL=C

print_row() {
  printf '%-30s | %-8s | %s\n' "$1" "$2" "$3"
}

check_var() {
  local label="$1" varname="$2"
  local value="${!varname:-}"
  if [ -n "$value" ]; then
    print_row "$label" "set" "$value"
  else
    print_row "$label" "unset" "-"
  fi
}

# ── Header ──
echo "=== Perimeter fingerprint ==="
echo "PWD: $PWD"
echo
print_row "Indicator" "Status" "Value"
print_row "------------------------------" "--------" "--------------"

# ── Direnv presence ──
check_var "DIRENV_DIR"          "DIRENV_DIR"
check_var "DIRENV_FILE"         "DIRENV_FILE"

# ── Sample sentinels ──
check_var "PERIMETER_ACTIVE"    "PERIMETER_ACTIVE"
check_var "PERIMETER_NAME"      "PERIMETER_NAME"

# ── Common scoped-credential targets (your .envrc may set these,
# leave them unset, or redirect them to /dev/null per cred-scrub) ──
check_var "AWS_PROFILE"         "AWS_PROFILE"
check_var "AWS_REGION"          "AWS_REGION"
check_var "KUBECONFIG"          "KUBECONFIG"
check_var "GITHUB_TOKEN"        "GITHUB_TOKEN"

# ── .envrc presence in current dir ──
if [ -f "$PWD/.envrc" ]; then
  print_row ".envrc here" "yes" "$PWD/.envrc"
else
  print_row ".envrc here" "no" "-"
fi

if [ -f "$PWD/.envrc.local" ]; then
  print_row ".envrc.local here" "yes" "$PWD/.envrc.local"
else
  print_row ".envrc.local here" "no" "-"
fi

echo
echo "Done."
