# Linux notes

Platform-specific notes for the Linux network-egress workshop.

## Why gluetun

`qmcgaw/gluetun:v3` is a popular all-in-one VPN container that supports many providers (Mullvad, ProtonVPN, NordVPN, AirVPN, Private Internet Access, custom OpenVPN configs, custom WireGuard configs, etc.). It's free, well-maintained, and uses a sensible firewall-as-default approach: when the tunnel is up, only tunnel traffic egresses; when it's down, nothing does. That fail-closed behavior is exactly what the workshop is teaching.

You can swap gluetun for any other VPN-sidecar pattern (a self-hosted WireGuard container, a custom OpenVPN container, mullvad-vpn's official container if it ever ships one). The shared-namespace trick — `network_mode: "service:other"` — works identically. Gluetun is just the convenient documented example.

## Why a Dockerfile

The worker image needs `curl`, `dig`, and `nc`. None of those are in the default `ubuntu:24.04` image. Two options:

- **Install them at startup** with `apt-get install` in the worker's command. But the worker shares gluetun's network namespace — when gluetun is failing closed, the worker has no internet, so `apt-get update` fails. The worker can't install its tools.
- **Bake them into a custom image** via Dockerfile. The build runs once, on the host (which has internet), and produces a self-contained image. The worker can then run the probes without needing internet to install its own tools.

The second option is what we do. The Dockerfile is small (5 lines) and the build takes ~30 seconds the first time, ~5 seconds on rebuilds.

## What `network_mode: "service:gluetun"` actually does

It tells Docker to put the worker container in the same Linux network namespace as the gluetun container. Practically:

- The worker has no `eth0` interface of its own — it sees gluetun's interfaces (`tun0` if the VPN is up; `lo` plus a docker bridge if it isn't and gluetun has fallen back).
- Routes are gluetun's routes.
- DNS resolution uses whatever resolver is reachable from gluetun's namespace.
- The worker can reach `localhost:<port>` to talk to anything gluetun has bound (gluetun exposes a control API on port 8000 by default).
- If gluetun is in firewall-deny state, the worker's egress is denied at the same point.

## What the failed gluetun startup looks like

Without VPN credentials, gluetun's logs will show messages like:

```
ERROR  WIREGUARD_PRIVATE_KEY environment variable not set
```

…and the container will either exit and restart (if `restart: unless-stopped`) or stay dead. The compose file uses `restart: unless-stopped`, so gluetun keeps trying. The worker is alive throughout (it's just `sleep infinity`); the probe inside it sees the failure-state network namespace.

## Common gotchas

- **`/dev/net/tun` not present.** Some minimal Linux setups don't have the TUN module loaded. `modprobe tun` on the host fixes it. Without `/dev/net/tun`, gluetun can't create the WireGuard interface.
- **Firewall on the host.** If your host has aggressive outbound filtering, gluetun may not be able to reach the VPN endpoint even with valid credentials. Check `iptables -L OUTPUT` if things are mysteriously failing.
- **DNS-over-UDP leaks.** The probe uses `getent hosts`, which goes through `nsswitch.conf` and uses whatever resolver is configured. Inside the namespace, that's gluetun's resolver. If you're seeing DNS work when the VPN is supposedly down, check what resolver gluetun is forwarding to.
- **IPv6 leak.** If your host has IPv6, the worker's namespace may inherit it. The compose file sets `IPV6=off` in gluetun for this reason. Don't remove it unless you know what you're doing.
- **Pulling images while disconnected.** First run needs internet to pull `qmcgaw/gluetun:v3` and (if not already pulled) `ubuntu:24.04`. If you're running this somewhere offline, pre-pull both.

## Cleanup

`run-via-sidecar.sh` ends with `docker compose down -v --remove-orphans`, which removes the worker, the gluetun container, and any compose-managed volumes. You can also clean up the workshop image when you're done with this topic:

```sh
docker image rm cybr-hak-con-egress:latest
```
