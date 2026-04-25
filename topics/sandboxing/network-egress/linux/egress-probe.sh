#!/usr/bin/env bash
# egress-probe.sh — what egress is actually reachable from this shell?
#
# Read-only. Doesn't modify anything. Probes:
#   - DNS resolution (getent hosts)
#   - HTTPS via DNS (curl example.com)
#   - HTTPS via direct IP (curl --resolve, bypassing local DNS)
#   - Exit IP detection (curl ipify)
#   - IPv6 reachability
#   - Raw TCP egress (nc to github:22)
#   - HTTP_PROXY / HTTPS_PROXY / ALL_PROXY / NO_PROXY env vars
#
# Output format: three columns separated by " | ".
#   Probe                   | Status      | Notes

set -uo pipefail
LC_ALL=C

print_row() {
  printf '%-26s | %-12s | %s\n' "$1" "$2" "$3"
}

# ── Header ──
echo "=== Egress probe ==="
echo "Date: $(date -Iseconds 2>/dev/null || date)"
echo
print_row "Probe" "Status" "Notes"
print_row "--------------------------" "------------" "--------------"

# ── DNS resolution ──
if getent hosts example.com >/dev/null 2>&1; then
  resolved=$(getent hosts example.com 2>/dev/null | awk '{print $1}' | head -1)
  print_row "DNS: example.com" "reachable" "${resolved:-resolved}"
else
  print_row "DNS: example.com" "fail" "could not resolve"
fi

# ── HTTPS via DNS ──
if command -v curl >/dev/null 2>&1; then
  if curl -sm 5 -o /dev/null -w '%{http_code}' https://example.com 2>/dev/null | grep -qE '^[23]'; then
    print_row "HTTPS: example.com" "reachable" "via DNS, valid TLS"
  else
    print_row "HTTPS: example.com" "fail" "connection failed or timed out"
  fi

  # ── HTTPS direct IP (no local DNS) ──
  if curl -sm 5 --resolve one.one.one.one:443:1.1.1.1 \
       -o /dev/null -w '%{http_code}' https://one.one.one.one 2>/dev/null | grep -qE '^[23]'; then
    print_row "HTTPS: 1.1.1.1 direct" "reachable" "TCP 443 to 1.1.1.1 OK"
  else
    print_row "HTTPS: 1.1.1.1 direct" "fail" "no direct IP egress"
  fi

  # ── Exit IP ──
  exit_ip=$(curl -sm 5 https://api.ipify.org 2>/dev/null)
  if [ -n "$exit_ip" ]; then
    print_row "Exit IP" "reachable" "$exit_ip"
  else
    print_row "Exit IP" "fail" "could not determine"
  fi

  # ── IPv6 ──
  exit_v6=$(curl -sm 5 -6 https://api6.ipify.org 2>/dev/null || true)
  if [ -n "$exit_v6" ]; then
    print_row "IPv6 egress" "reachable" "$exit_v6"
  else
    print_row "IPv6 egress" "fail" "no IPv6 connectivity"
  fi
else
  print_row "HTTPS tests" "n/a" "curl not installed"
fi

# ── Raw TCP via netcat ──
if command -v nc >/dev/null 2>&1; then
  if nc -z -w 3 github.com 22 2>/dev/null; then
    print_row "TCP 22 (raw): github" "reachable" "non-HTTP egress works"
  else
    print_row "TCP 22 (raw): github" "fail" "no TCP egress on 22"
  fi
else
  print_row "Raw TCP" "n/a" "nc not installed"
fi

# ── Proxy env vars ──
for var in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
  v="${!var:-}"
  if [ -n "$v" ]; then
    print_row "$var" "set" "$v"
  else
    print_row "$var" "unset" "-"
  fi
done

echo
echo "Done."
