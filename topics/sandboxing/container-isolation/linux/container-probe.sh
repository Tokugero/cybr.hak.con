#!/usr/bin/env bash
# container-probe.sh — what's the shape of this shell?
# Specifically: am I in a container, and if so, how locked-down is it?
#
# Read-only. Reports:
#   - The shell's identity (uid, gid)
#   - Container detection (/.dockerenv, cgroup hint, mount hint)
#   - PID 1 (so you can spot the container's entrypoint)
#   - Linux capabilities (via /proc/self/status CapEff)
#   - Network namespace state (interfaces, routes)
#   - Root filesystem writability
#   - Docker socket reachability
#   - /tmp writability
#
# Output format: three columns separated by " | ".
#   Indicator                  | Status       | Value

set -uo pipefail
LC_ALL=C

print_row() {
  printf '%-26s | %-12s | %s\n' "$1" "$2" "$3"
}

# ── Header ──
echo "=== Container shape probe ==="
echo "Date: $(date -Iseconds 2>/dev/null || date)"
echo
print_row "Indicator" "Status" "Value"
print_row "--------------------------" "------------" "--------------"

# ── Identity ──
my_uid=$(id -u)
my_gid=$(id -g)
my_uname=$(id -un 2>/dev/null) || my_uname="?"
my_gname=$(id -gn 2>/dev/null) || my_gname="?"
print_row "uid" "$my_uid" "$my_uname"
print_row "gid" "$my_gid" "$my_gname"

# ── Container detection ──
if [ -f /.dockerenv ]; then
  print_row "container" "yes" "/.dockerenv exists (Docker)"
elif grep -qE 'docker|kubepods|containerd|podman|libpod' /proc/1/cgroup 2>/dev/null; then
  hint=$(awk -F: '{print $3}' /proc/1/cgroup 2>/dev/null | head -1)
  print_row "container" "yes" "cgroup: ${hint:-(unspecified)}"
elif [ -r /proc/1/mountinfo ] && [ "$(awk '$5=="/"{print $4}' /proc/1/mountinfo 2>/dev/null | head -1)" != "/" ]; then
  print_row "container" "likely" "rootfs is not /"
else
  print_row "container" "no" "appears to be host or VM"
fi

# ── PID 1 ──
if [ -r /proc/1/comm ]; then
  print_row "pid 1" "info" "$(cat /proc/1/comm 2>/dev/null)"
fi

# ── Capabilities ──
if [ -r /proc/self/status ]; then
  capeff=$(awk '/^CapEff:/ {print $2}' /proc/self/status)
  if [ "$capeff" = "0000000000000000" ]; then
    print_row "Capabilities" "all dropped" "CapEff=0"
  elif [ -z "$capeff" ]; then
    print_row "Capabilities" "unknown" "CapEff not readable"
  else
    print_row "Capabilities" "non-zero" "CapEff=0x$capeff"
  fi
fi

# ── Network namespace ──
if [ -r /proc/self/net/route ]; then
  routes=$(($(wc -l < /proc/self/net/route 2>/dev/null) - 1))
  if [ "$routes" -le 0 ]; then
    print_row "Network namespace" "isolated" "no routes"
  else
    print_row "Network namespace" "active" "$routes route(s) in table"
  fi
else
  print_row "Network namespace" "unknown" "/proc/self/net/route not readable"
fi

# ── Root filesystem writability ──
if touch /.write-test 2>/dev/null; then
  rm -f /.write-test 2>/dev/null
  print_row "Root filesystem" "writable" "/ is writable"
else
  print_row "Root filesystem" "read-only" "/ is read-only"
fi

# ── Docker socket reachability ──
if [ -S /var/run/docker.sock ]; then
  if [ -r /var/run/docker.sock ] && [ -w /var/run/docker.sock ]; then
    print_row "Docker socket" "reachable" "/var/run/docker.sock readable+writable -- host control plane exposed"
  elif [ -r /var/run/docker.sock ]; then
    print_row "Docker socket" "exposed" "readable but not writable"
  else
    print_row "Docker socket" "exists" "present but not readable from this user"
  fi
else
  print_row "Docker socket" "absent" "-"
fi

# ── /tmp writability ──
if touch /tmp/.write-test 2>/dev/null; then
  rm -f /tmp/.write-test 2>/dev/null
  print_row "/tmp" "writable" "-"
else
  print_row "/tmp" "read-only" "-"
fi

echo
echo "Done."
