# Discussion: composition

Questions to hand to your LLM after the workshop. Most of these ask you to *reason* about a setup — that's the skill the topic is teaching.

## Reading existing setups

- "Look at this `docker run` invocation: `docker run --rm -v $HOME/.aws:/root/.aws -v /var/run/docker.sock:/var/run/docker.sock ubuntu bash`. Walk through the matrix in `workshop.md` §3 and tell me what each S1–S4 row should be. Which lines are closed, which are open, which are *worse* than running on the host?"
- "Compare these two compositions: (a) bwrap with `--unshare-all` and a `~/sandbox-only` bind, versus (b) Docker with `--user $(id -u)`, `--network=none`, `--read-only`, and a `~/sandbox-only` bind-mount. They both look 'tight' — what's actually different about them as defenses?"
- "I'm reading a `compose.yml` someone gave me. What three things should I check first to decide whether the network is actually isolated?"

## Writing for a scenario

- "I want to evaluate a CTF binary that probably tries to make outbound connections. Sketch the composition I should use, justifying each layer."
- "Sketch a composition for running a Claude Code subagent against an unfamiliar GitHub repo. What's in scope, what's out, what does the agent need (and not need) for the work?"
- "I have a directory with prod credentials I need an agent to use, but only briefly. Walk me through scope-then-time-box plus container-isolation, plus what's not the right answer here."

## Picking and skipping layers

- "When is it the *wrong* call to add Tier 1 or Tier 2 to a Tier 0 setup? Give me a concrete example where the over-engineering tax beats the threat-model gain."
- "Why does the matrix in `workshop.md` show 'Tier 0 alone' as `partial` for S3 (scope creep)? What part is closed by Tier 0 and what part isn't?"
- "If my workflow is 'agent edits my own code in my own repo,' what's the smallest sandbox that's still doing useful work? Defend the answer."

## Composition with the agent's own controls

- "Claude Code has a permission allowlist. How does that compose with the OS-level sandbox layers in the matrix? Are they redundant, additive, or do they protect different things?"
- "Sketch what a 'well-scoped agent inside a leaky sandbox' looks like, and what 'permissive agent inside a hardened sandbox' looks like. Which is more dangerous, and under what threat model?"

## Failure-mode thinking

- "I composed Tier 0 + Docker hardened + egress sidecar. The agent did something unexpected — it `curl`-ed an internal IP I didn't know about. Walk me backwards through where the layer order would have caught this."
- "If a malicious `.envrc` is allowed in the parent shell, every layer above inherits poisoned scope. Where in the composition does this fail open, and how would I detect it?"
- "What's an attack that defeats every layer in the rightmost column of the matrix simultaneously?"

## Pushing into Tier 3

- "If I added a VM (Tier 3) to the composition, which row of the matrix changes? Be specific about what kernel-level attacker this addresses that the lower tiers don't."
- "Compare the cost of Tier 0 + bwrap against Tier 0 + Docker against Tier 0 + Docker + VM. Where does the cost climb steeply, and where does it climb cheaply for a meaningful threat-model gain?"
