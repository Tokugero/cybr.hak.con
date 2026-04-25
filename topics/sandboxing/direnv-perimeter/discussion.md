# Discussion: direnv-perimeter

Questions to hand to your LLM after the workshop. Open-ended on purpose.

## Understanding what just happened

- "Walk me through what happens, step by step, when I `cd` into a directory with an allowed `.envrc`. What does the shell call, what does direnv read, what gets exported?"
- "What's the difference between direnv's hook firing and direnv's `.envrc` actually running? When can the second happen without the first?"
- "If I `cd` from one perimeter to another (without going through `~`), what does direnv do?"

## Composing patterns

- "Look at `patterns.md`. Walk me through integrating `aws-vault exec` into my `.envrc` from scratch. What do I need to set up beforehand, what does the `.envrc` look like, how do I confirm the scoping is what I think it is?"
- "I have an existing `~/.kube/config` with three contexts. How do I create a per-directory kubeconfig that points at one of them with a narrower service account, without affecting my main one?"
- "Write me a starter `.envrc` for a CTF engagement that combines: (a) the `cred-scrub` two-layer scrubber, (b) a scoped AWS profile, (c) a per-directory kubeconfig, (d) a sourced `.envrc.local` for any extra secrets. Walk me through each section so I understand what it's doing."

## Threat-model thinking

- "Compare a single committed `.envrc` against the `.envrc` + `.envrc.local` pattern. Concretely, which threats does the split address that the single file doesn't?"
- "If my agent edits `.envrc` while I'm working with it (e.g., to 'help me set up the perimeter'), what happens? Will direnv warn me, or will the changes silently apply on the next `cd`?"
- "What's the threat model where the `.envrc.local` pattern provides zero defense?"
- "I keep my AWS credentials in 1Password. Is the perimeter still useful for me, or does the keystore make it redundant? What does each one defend that the other doesn't?"

## Verifying scope

- "I'm in a perimeter directory. How do I prove to myself that a Python script I'm about to run will only see the scoped credentials, not my real ones?"
- "If I run `bash` from inside a perimeter, then run my agent inside that bash, then run a tool inside the agent, how many layers of inheritance is that and where can the perimeter fail to apply?"
- "Walk me through using the verification recipe (plain bash vs `direnv exec`) on three different commands my LLM might run. How do I tell which is honest about the perimeter and which is leaking my parent shell's env?"

## Failure modes

- "What's a scenario where running `direnv allow` is the wrong move, even on a file I just wrote myself?"
- "Suppose I `cd` into a perimeter, start a `tmux` session, then `cd` out. What env does the `tmux` session have? What about a process inside the `tmux` session?"
- "Could a malicious `.envrc` set up its own perimeter that *looks* scrubbed (the fingerprint shows the right values) but actually leaks credentials some other way? What would that look like?"

## Composition with higher tiers

- "Read `topics/sandboxing/README.md`. The talk frames Tier 0 as composing with Tier 2 (containers) — the AssumeRole-plus-container pattern. Sketch how the directory perimeter and a Docker container would compose for a single engagement. What does each layer contribute?"
- "If I'm running an agent inside a Tier 2 container, and the container has my home directory mounted, how much of the perimeter survives the boundary?"
