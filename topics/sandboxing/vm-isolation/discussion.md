# Discussion: vm-isolation

Questions for your LLM after the workshop.

## Understanding what just happened

- "Compare the kernel release inside the VM and on my host. What does the difference actually mean for an attacker who has a kernel-level exploit?"
- "Walk me through every step `launch-and-probe.sh` takes. Which steps are about isolation, and which are just operational plumbing (image caching, SSH key, cloud-init seed)?"
- "Why does the container-shape probe inside the VM show `container | no` even though we're inside qemu? Trace what each detection method is looking for and why none of them fire for a VM."

## Cost versus value

- "Concretely, what threats does this VM-based setup defend against that the hardened Docker container doesn't? Be specific about which Linux kernel features the VM isolates and the container shares."
- "What's a workload where running every agent invocation in a VM is *worth* the 30-second boot tax? What's one where it isn't?"
- "Compare 1 GB of RAM and 30 seconds of boot for a VM against 0 RAM overhead and 2 seconds for a container. Where's the break-even on threat-model gain?"

## Composition with the rest of the track

- "Walk me through composing Tier 0 (cred-scrub) + this VM + a hardened Docker container running inside the VM. Sketch the runner script. What does each layer contribute that the others don't?"
- "If I'm running a Claude Code subagent inside this VM, where does the subagent's process tree live, and which isolation layer applies to which part of the agent's behavior?"
- "Compare 'Linux host with VM and container' against 'Mac host with Docker Desktop' (which is already a VM). Are they the same threat model? Where do they differ?"

## When VMs aren't enough

- "What's a hypervisor-escape CVE? Has KVM had any in the last 5 years? How does that change my threat model?"
- "If I'm worried about someone with a 0-day for the host kernel *and* a 0-day for KVM, what's the next tier up? (Hint: it's a different physical machine or a different cloud account.)"
- "What's the difference between QEMU/KVM and a microVM (Firecracker, Cloud Hypervisor)? When would I reach for the latter?"

## Cloud-init and image hygiene

- "What's actually in the Ubuntu 24.04 cloud image? How do I audit it? Walk me through verifying the SHA against canonical."
- "If a malicious actor controlled the cloud image's mirror, what could they do? How would I detect it?"
- "I want to add specific packages to the VM at first boot. Walk me through extending the cloud-init user-data to do that."
- "Could I use a smaller base image (Alpine, Debian minimal)? What changes about the workshop, and what's the cost?"

## Tier 3 on Mac/Windows

- "Mac users running Docker Desktop have an implicit VM. What's the trust boundary for them? What CVE class would still bite Mac users?"
- "Windows Sandbox is built into Windows. What does it isolate, and how does it compare to running my own Hyper-V VM?"
- "Lima and Colima on Mac let you run a Linux VM with `docker compose` inside. Are they the same security model as Docker Desktop, or different?"

## Operational concerns

- "What's a sensible policy for when to nuke the cached VM image and overlay disk? Once a week? After every CTF? What does each cadence cost vs gain?"
- "If I'm running multiple agent VMs concurrently (different ports, different overlays), what's the resource model? Can my laptop handle five at once?"
- "How would I make this work on a server with no display, behind a corporate proxy, with a tightly-controlled outbound firewall?"
