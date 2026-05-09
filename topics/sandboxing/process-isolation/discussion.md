# Discussion: process-isolation

Questions for your LLM after the workshop.

## Understanding what just happened

- "Walk me through every flag in `bwrap-hardened.sh` and tell me what would change if I removed each one. Which removals matter most for an agent context?"
- "Compare the cred-scrub probe output from inside the permissive bwrap to the hardened bwrap. Which rows changed because of what binds, and which changed because of what `--unshare-*` flags?"
- "Why does the hardened bwrap show `~/.aws` as `clean` but inside the same shell I can still `ls /workshop/cred-scrub/linux/probe.sh`? Trace the bind logic."

## Building your own bwrap invocations

- "Write me a `bwrap` invocation that gives me only `~/sandbox-test` (read-write) and `<repo>/topics/sandboxing` (read-only). Nothing else from my home, no network, no procfs from the host."
- "I want to run an LLM agent inside a bwrap that has access to one specific directory and the network, but nothing else. Sketch the full command including the `--unshare-*` choices."
- "Compare these two: `bwrap --bind / / ... bash` versus `bwrap --ro-bind /usr /usr --ro-bind /etc /etc ... bash`. What's the difference an attacker inside each one would notice?"

## bwrap vs containers

- "I'm trying to decide between wrapping a single agent command in `bwrap` versus running it in a Docker container. Walk me through the trade-offs for each."
- "The talk says 'no daemon, no image' is bwrap's main ergonomics win. Concretely, what *kinds* of work change because of that?"
- "If I'm already running an agent in a Docker container, is there ever a reason to also `bwrap` the command inside it? Or is that just security theater?"

## Composition

- "Sketch the composition: cred-scrub `.envrc` on the host, then `bwrap --unshare-net` for one specific command. What's each layer adding that the other doesn't?"
- "Compare these two compositions: (a) cred-scrub + bwrap with `--unshare-net`, and (b) cred-scrub + container-isolation hardened. They both deny network egress. What's actually different about them as defenses?"
- "I want to combine bwrap with the network-egress topic's gluetun sidecar. How would I send bwrap traffic through the sidecar? (Hint: it's not trivial.)"

## Failure modes

- "What's the worst-case `bwrap` invocation someone might write thinking it isolates them when it doesn't?"
- "Does `bwrap` have anything analogous to `--privileged` in Docker? Are there flags that completely undo the isolation?"
- "Suppose a malicious agent inside a bwrap calls `bwrap --bind / / bash` itself. What happens? Does my outer hardening still apply?"
- "If `bwrap` itself is compromised (a CVE in the binary or its setuid logic), what's the failure mode for everyone running it?"

## Going further

- "Read about `firejail`. When would I use it instead of `bwrap`?"
- "Linux's Landlock LSM is sometimes mentioned alongside bubblewrap. What does Landlock add, and is it worth using if bwrap is already in place?"
- "What's `flatpak-spawn`? It's bwrap-adjacent but with a different threat model — explain."

## Translating to your platform

The workshop ships a Linux bwrap implementation. Mac and Windows participants: drive your agent through the port with these.

- "Read `OTHER-PLATFORMS.md`, then translate `linux/bwrap-hardened.sh` into `mac/sandbox-hardened.sh` using `sandbox-exec`. Remember: sandbox-exec profiles are *allow-lists* — the inverse of bwrap's bind list. Show me the profile and walk me through what's allowed vs denied."
- "I'm on Windows. Per `OTHER-PLATFORMS.md`, the practitioner answer is WSL 2 + the Linux folder. Argue both sides: when is that the right call, and when is it a cop-out that misses a real Windows-native need (AppContainer, Windows Sandbox)?"
- "After your Mac port exists, compare the cred-scrub probe's output inside `bwrap-hardened` (Linux) vs inside `sandbox-hardened` (Mac). The threat goal is identical — block reads outside the workshop dir. Do the probe rows agree? If not, is the disagreement a Mac platform reality or a profile bug?"
