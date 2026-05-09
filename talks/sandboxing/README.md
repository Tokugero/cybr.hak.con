# Sandboxing AI Coding Agents — talk for Cybr Hak Con

Approver-facing summary for the sandboxing-track talk. Title and executive summary are the version to share with reviewers; the line-item table of contents below is the structural follow-up for that conversation.

## Title

**Primary:** *When Your Agent Tries Too Hard: Layered Sandboxing for AI Coding Tools*

The primary leans into the talk's reframe — the agent's enthusiasm is the threat, not its malice — and signals empathy-first content for a security crowd rather than another "AI is dangerous" warning.

**Alternate (drier, more conventional):** *Composing Sandboxes for AI Coding Agents: A Practitioner's Tour*

The alternate is safer if approvers want something less editorial; it foregrounds the technical content over the rhetorical move.

## Executive summary

The security threat from AI coding agents is not malicious behavior; it is overcompliance. Most security framing of agentic AI treats the model as an adversary to be locked down, which pushes practitioners away from using the technology rather than helping them use it well. This talk reframes the threat as enthusiastic agents doing too much to satisfy your requests, then walks the audience through a practical mental model for choosing how much containment each task warrants.

The structure follows the workshop repo's tier ladder, from Tier 0 hygiene through Tier 3 virtualization, with honest framing at each step about what each tier protects against and what it does not. The talk's distinctive content is composition: how the speaker actually stacks tiers in real workflows, including the platform realities most attendees will encounter when they try the workshops the same afternoon (Docker Desktop on Mac and Windows providing Tier 3 isolation by accident, what hardened Docker actually means in practice, when fail-closed network egress matters and when it does not). Demos run as visual backdrop, using asciinema captures and probe-output diffs from the workshop repo, with live narration over them.

The audience is the technically apt, security-fluent crowd expected at Cybr Hak Con. The talk runs thirty to forty minutes, leaves attendees with a single concrete next step they can complete that night (a cred-scrub `.envrc` on the project their agent is already in), and seeds the afternoon's hands-on workshops without depending on them. The takeaway is that layered defense lets practitioners use agents more confidently, not less.

## Contents (line-item)

1. **Opening: the reframe** (3–4 min) — the threat from coding agents is enthusiasm, not malice
2. **The threat shapes** (4 min) — S1 cred exfil via poisoned context, S2 supply chain via add-ons, S3 scope creep including overcompliance, S4 persistence and lateral movement
3. **The tier ladder** (4 min) — T0 hygiene, T1 process isolation, T2 containers, T3 virtualization, T4 physical or account isolation
4. **T0 hygiene: the cheapest tier that pays for itself** (5 min) — cred-scrub and direnv-perimeter, with probe-before/probe-after as backdrop
5. **T1 through T3: what each tier actually buys you** (8 min) — bubblewrap, hardened Docker, qemu plus cloud-init, with probe diffs as backdrop
6. **How I actually use this: composition** (8 min) — real workflow patterns, the Docker-Desktop-is-a-VM platform reality, fail-closed network egress
7. **What sandboxing does not fix** (3 min) — prompt injection, jailbreaks, model errors, social engineering through authorized tools
8. **Closing: feel safer, not less** (4 min) — single concrete next-step, pointer to the workshop repo

Total runs to forty minutes including transitions; compressible to thirty by trimming sections 5 and 6.
