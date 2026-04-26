# Workshop: VM isolation

Hands-on. You'll boot a fresh Ubuntu VM, run the cred-scrub probe and container-shape probe inside it, observe the kernel difference, then shut it down. The whole cycle takes ~60-90 seconds after the first-run image download.

## 1. What a VM actually isolates

A VM, run by a hypervisor (KVM here, via QEMU), has:

- **Its own Linux kernel.** Different from the host. A kernel CVE that exploits one doesn't trivially translate to the other.
- **Its own device model.** The VM sees emulated or paravirtualized devices (`virtio-net`, `virtio-blk`, etc.), not your host's hardware.
- **A separate `/proc`, `/sys`, `/dev`.** Everything the kernel exposes is the VM's, not the host's.
- **No shared filesystem unless you opt in.** Your home directory, your dotfiles, your SSH agent — none reachable from inside the VM unless you mounted/forwarded them.

That last point is the big practical difference from a container. Containers share the host's kernel; VMs share *nothing* except CPU and RAM (via the hypervisor).

## 2. The cost

Real numbers for the Ubuntu cloud image used in this workshop:

- **Disk:** ~600 MB cached image, plus a per-VM overlay disk (typically <100 MB after install).
- **RAM:** 1 GB allocated by default (the launch script's `-m 1G`). Can go lower for minimal workloads.
- **Boot time:** ~30 seconds with KVM, ~2 minutes without (TCG software emulation).
- **Setup complexity:** medium. Cloud-init handles the user provisioning, but you have to generate the seed ISO and orchestrate the SSH-after-boot pattern.

If your threat model doesn't include kernel-level attackers, this cost might not be worth paying for every agent invocation. If it does, this is the only option short of a separate physical machine.

## 3. Boot, probe, shut down

```sh
bash <repo>/topics/sandboxing/vm-isolation/linux/launch-and-probe.sh
```

What this does, in order:

1. **Caches the Ubuntu cloud image** at `~/.cache/cybr-hak-con-vm/` if not present. ~600 MB download on first run.
2. **Generates an SSH keypair** at `~/.cache/cybr-hak-con-vm/ssh_key` (cached for re-use).
3. **Builds a cloud-init seed ISO** with the SSH public key, so the VM auto-creates an `agent` user with passwordless sudo and the public key authorized.
4. **Creates a qcow2 overlay disk** on top of the cached cloud image — your changes don't touch the base.
5. **Boots qemu** in the background with KVM acceleration if available. User-mode networking forwards `localhost:2222` -> `guest:22`.
6. **Waits for SSH** to become reachable (up to ~3 minutes; usually 30-60 seconds).
7. **Copies the cred-scrub and container-shape probes** into the VM via `scp`.
8. **Runs both probes** inside the VM via `ssh`.
9. **Captures the kernel difference** — `uname -r` on host vs guest.
10. **Shuts down** by killing the qemu process. The overlay disk stays cached for the next run.

## 4. Reading the output

Inside the VM, the cred-scrub probe should show:

- **All env-var rows clean.** The VM started with cloud-init's minimal env. Your host env didn't leak in.
- **All dotfile rows clean.** No `~/.aws`, `~/.kube`, etc. — the VM's `/home/agent` is fresh.
- **SSH agent clean** — no `SSH_AUTH_SOCK` is set (you connected via key auth, not agent forwarding).
- **OS keystore rows `n/a` or `clean`.** The VM has no GNOME Keyring, no `pass`, no Keychain.

The container-shape probe should show:

- **`uid 1000`, name `agent`** — the cloud-init user.
- **Container detection: `no`** (no `/.dockerenv`, no docker/kubepods cgroup hint). This is *not* a container; it's a VM.
- **PID 1: probably `systemd`** — the VM has a real init system, not a single bash process like a container.
- **Capabilities non-zero** — root inside the VM (or the user's caps) — but that's *VM root*, which has no relationship to host root.
- **Network namespace active.** The VM has its own routing table via the user-mode network.
- **Root filesystem writable** — the overlay disk.

The **kernel comparison** at the end should show two different kernel release strings. That's the point: the VM has its own kernel, which is the row of the matrix that every Tier 0/1/2 column has open.

## 5. Composition with Tier 0 and Tier 2

A VM around a hardened Docker container is the strongest practical composition on Linux. The pattern:

```sh
# Host: Tier 0 scrubbed shell (cred-scrub + direnv-perimeter)
cd ~/scrubbed-project

# Boot the VM, ssh in, do the work in a hardened container inside the VM
bash <repo>/topics/sandboxing/vm-isolation/linux/launch-and-probe.sh
# (or your own variant that runs `docker run --user --network=none ...` inside the VM)
```

What each layer adds:

- **Tier 0** scopes the host shell so even setup commands run with minimum credentials.
- **VM (Tier 3)** isolates the kernel. A kernel-level escape inside the VM is one CVE removed from your host kernel.
- **Hardened container inside the VM (Tier 2)** isolates the agent further from the VM's userspace. If the agent escapes the container, it's still inside the VM.

Defense in depth: each layer addresses a class of attack the others don't.

## 6. The implicit Tier 3 on Mac/Windows

If you're on Mac or Windows running Docker Desktop, your "Tier 2 container" *is already* running inside a Linux VM. Docker Desktop spins up a hypervisor (Hyperkit on Mac, Hyper-V on Windows) to host a Linux kernel that runs your containers. So Mac/Windows users have an *implicit* Tier 3 layer they didn't ask for.

That has two interesting consequences:

- The "kernel attack surface" row of the matrix is closed for Mac/Windows users **even at Tier 2**, because the kernel that's "shared" by their container is the VM's, not the host's.
- Cross-platform performance comparisons of containers are misleading. They mostly measure hypervisor overhead, not container overhead.

A Linux user who wants the same defense has to build it explicitly — that's what this workshop teaches. A Mac/Windows user could argue they don't need this topic at all; their threat model is already addressed by the architecture they're using. That's a fair argument, with one caveat: the trust boundary moves to *Docker Desktop's* hypervisor, which is its own surface.

## 7. Honest gaps

- **Hypervisor escape CVEs.** QEMU and KVM have had their own vulnerabilities. The trust boundary moves to the hypervisor; it doesn't disappear.
- **Image trust.** The Ubuntu cloud image is widely trusted. A random `someuser/sketchy.qcow2` is not.
- **Cloud-init exposure.** The seed ISO contains your SSH public key. Anyone who can read the cached files knows what key authorizes you to the agent VM. Not a credential leak (public key is meant to be public), but worth being aware of.
- **VM persistence.** The overlay disk is kept cached unless you `cleanup.sh` it. If you boot, do work, then *don't* shut down cleanly, the overlay's state persists. Treat the overlay as ephemeral and rerun `cleanup.sh` between sessions.
- **Network is fully reachable.** The default user-mode network gives the VM internet access via NAT. Combine with network-egress patterns (a VPN sidecar inside the VM, or VM-level routes that fail-closed) for the full network-axis story.

## 8. Where to next

`discussion.md` has prompts:

- "Walk me through what a kernel CVE that escapes a container would look like, and how a VM defense changes the attack chain."
- "If I'm on Mac and Docker Desktop is already a VM, why would I ever need this topic? Argue both sides."
- "Compose Tier 0 + this VM + a hardened Docker container *inside* the VM. Sketch the runner script."

The cleanup script (`cleanup.sh`) tears down any leftover qemu processes and removes the cached overlay disk. Run it between sessions if you want the VM truly disposable.
