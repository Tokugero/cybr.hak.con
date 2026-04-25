# Discussion: container-isolation

Questions to hand to your LLM after the workshop. Open-ended on purpose.

## Understanding what just happened

- "Walk me through the difference between the default Docker container and the hardened one. Which flags did the most work, and which were defense-in-depth?"
- "I saw `uid 0` inside the default container even though I'm a non-root user on the host. What's actually happening with user namespaces here?"
- "Read the cred-scrub probe output from inside the hardened container. Why are the dotfile rows mostly `clean`? Where would they be `present` instead, and what would I have to do to make that happen?"

## Hardening choices

- "Walk me through the difference between `--user=$(id -u):$(id -g)` and rootless Docker. What does each one address that the other doesn't?"
- "What's the threat model where `--network=none` is overkill, and what's the threat model where it's the minimum I should accept?"
- "What does `--cap-drop=ALL` actually take away? Pick three Linux capabilities and explain what an agent loses without them."
- "If I want my container to be able to install packages but nothing else, what's the smallest set of flags I'd relax, and what does that re-enable?"

## Composition with Tier 0

- "Sketch a `docker run` invocation that lets me run a Claude Code subagent against an unfamiliar repo, with cred-scrub + direnv-perimeter + container hardening composed correctly. What does each layer contribute?"
- "I want to give my container a scoped GitHub token, a kubeconfig, and read-only access to my project directory. Walk me through the right way to pass each in, and what's wrong with `-v $HOME:/host-home`."
- "If I'm using `aws-vault exec` outside the container to fetch credentials, how do I forward those credentials *into* the container without leaving them in my shell history?"

## Mac / Windows specifics

- "If I'm on Mac and the container is already running inside a Linux VM (Docker Desktop), do I still need `--cap-drop=ALL`? Walk me through what changes about the threat model."
- "Compare `docker run` on Linux native vs Docker Desktop on Mac. What's the same about the security boundary, and what's different?"
- "How does a Mac/Windows container's `/proc/1/cgroup` differ from a Linux native one? What does that tell me about what's actually running?"

## Failure modes

- "I'm reading a `Dockerfile` and `docker run` invocation an agent suggested. What are the three things I should look at first to know whether I'd be undoing the hardening?"
- "Suppose an MCP server config in my `.mcp.json` says `command: docker` with arbitrary args. How do I evaluate whether the resulting container runs hardened or not?"
- "What does `--privileged` do, and what's a scenario where someone might be tempted to use it that they should not?"
- "Walk me through how a container with `/var/run/docker.sock` mounted is *worse than no container at all*."

## Composition with higher tiers

- "Read `topics/sandboxing/README.md` for the tier framing. Sketch the composition story for `Tier 0 + Tier 2 + Tier 3` — Tier 0 hygiene + container + a VM around it. What does each layer add to the others?"
- "Firecracker microVMs are sometimes called 'container-fast, VM-strong.' Where does that fit in the tier framework, and what's the practical difference for an agent workload?"
