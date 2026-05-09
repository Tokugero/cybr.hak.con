# VM isolation

A workshop on Tier 3 sandboxing: running an AI coding agent inside a full virtual machine. The VM has its *own* kernel, which closes the one row of the talk's matrix that every Tier 0/1/2 column has open: kernel attack surface.

## What you'll learn

- What a VM isolates that a container doesn't (kernel, all of `/proc`, fully separate device model).
- The cost of a VM (boot time, RAM, image size, complexity) and when it's worth paying.
- How a minimal `qemu-system-x86_64` invocation with a cloud-init Debian image gives you a disposable agent sandbox in ~30 seconds.
- The composition story: VM around a hardened container = the strongest practical setup on Linux.
- The implicit Tier 3 that Mac/Windows users get via Docker Desktop/WSL2 — which is its own teaching point.

## Threats addressed

- **S1 (credential exfiltration)** — fresh VM, fresh user, no host filesystem mounted unless you opt in. Filesystem reach is whatever you `scp` into the VM.
- **S2 (supply chain)** — a malicious add-on inside the VM has no path to the host without a kernel-level escape.
- **S3 (scope creep)** — same as filesystem isolation; the agent only sees what's in the VM.
- **S4 (persistence)** — disposable VM (overlay disk, destroyed at end) means nothing the agent writes survives the session.
- **Kernel attack surface** — *only* a VM addresses this. Containers share the host kernel; VMs don't.

For the full threat model and tier vocabulary, see `../README.md`.

## Why VMs are the cost-versus-value step

Going from no isolation to Tier 0 hygiene costs almost nothing. Tier 0 → Tier 1/2 costs a few seconds per command and some setup complexity. **Tier 2 → Tier 3 costs roughly 30 seconds of boot time, a gigabyte of RAM, and ~350 MB of disk.** That's a real step-change.

What you buy: kernel isolation. If your threat model includes "an attacker with a kernel CVE can escape my container," a VM is what you need.

What it doesn't buy: hypervisor isolation isn't free either. QEMU has had its own CVE history. The trust boundary moves; it doesn't disappear.

## What you need

- A Linux host with KVM available (`/dev/kvm` exists and is readable). Without KVM, qemu falls back to TCG software emulation, which works but is much slower (~3-5x boot time).
- `qemu-system-x86_64`. Install via your package manager (`apt install qemu-system-x86`, `pacman -S qemu`, etc.).
- `cloud-localds` from the `cloud-utils` (or `cloud-image-utils`) package. Used to generate the cloud-init seed ISO.
- ~350 MB of disk for the cached Debian 12 generic-cloud image (one-time download).
- An internet connection on first run, to download the image.
- Mac and Windows participants: see `OTHER-PLATFORMS.md`.

The cred-scrub probe and container-shape probe are reused — copied into the VM via `scp` and run there.

## Recommended: prefetch the night before

The image download is the only step that needs reliable internet. Run this from your hotel/home wifi the night before; the workshop step then runs offline.

```sh
bash topics/sandboxing/vm-isolation/linux/prefetch.sh
```

It downloads the Debian image, generates the SSH keypair, and builds the cloud-init seed ISO into `~/.cache/cybr-hak-con-vm/`. Idempotent — re-running is a no-op once the cache is warm. After this, `launch-and-probe.sh` boots without touching the network.

## Time

- With prefetch done: ~60-90 seconds total (boot + probe + shutdown).
- Without prefetch, first run: ~3 minutes on fast wifi; longer on conference wifi.
- Including reading the workshop and running the discussion prompts: ~75 minutes total.

## Layout

```
README.md                — this file
workshop.md              — the exercise
discussion.md            — questions to ask your LLM
OTHER-PLATFORMS.md       — pointers for translating linux/ to Mac (Lima) or Windows (Windows Sandbox / Hyper-V)
linux/
  prefetch.sh            — downloads image + keys + seed (run the night before)
  launch-and-probe.sh    — boots a VM, runs probes via SSH, shuts down
  cleanup.sh             — tears down any leftover VM, removes cached overlay
  notes.md               — Linux-specific notes (KVM, image cache, custom user-data)
  tests/run.sh           — runs the full lifecycle; opt-in via RUN_VM_HARNESS=1 because expensive
```

WSL users follow the Linux folder. Mac and Windows participants: see `OTHER-PLATFORMS.md`.
