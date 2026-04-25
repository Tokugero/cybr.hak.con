#!/usr/bin/env bash
# Bring up the gluetun + worker docker-compose stack, run the egress
# probe inside the worker (which shares gluetun's network namespace),
# tear down.
#
# Without VPN credentials in .env, gluetun won't establish a tunnel
# but its firewall rules are in place. The worker, sharing gluetun's
# namespace, has no usable network — fail-closed.
#
# With credentials in .env, the worker's traffic exits via your VPN.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

# Build the worker image (compose can do this implicitly, but doing it
# explicitly here gives cleaner output)
if ! docker image inspect cybr-hak-con-egress:latest >/dev/null 2>&1; then
  echo "Building cybr-hak-con-egress image (one-time, ~30s)..."
  docker build -q -t cybr-hak-con-egress:latest . >/dev/null
  echo "Built."
fi

# Bring up the stack. Use --no-color for cleaner test-harness output.
echo "Bringing up gluetun + worker stack..."
docker compose up -d --no-color 2>&1 | sed 's/^/  /'

# Give gluetun a few seconds to set up its network namespace and
# firewall rules, even if it can't actually authenticate.
echo
echo "Waiting 8s for gluetun to set up tunnel namespace..."
sleep 8

echo
echo "Running egress-probe inside worker (sharing gluetun's namespace):"
echo

# -T disables pseudo-TTY allocation for non-interactive use
docker compose exec -T worker bash /workshop/network-egress/linux/egress-probe.sh || true

echo
echo "Tearing down stack..."
docker compose down -v --remove-orphans 2>&1 | sed 's/^/  /'
