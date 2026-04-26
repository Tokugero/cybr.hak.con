# Linux notes

Platform-specific notes for the Linux vm-isolation workshop.

## What `launch-and-probe.sh` actually does

The script does seven things, in order:

1. **Caches the Ubuntu cloud image.** First run downloads ~600 MB; cached at `~/.cache/cybr-hak-con-vm/`. Subsequent runs reuse it.
2. **Generates an SSH keypair** at `~/.cache/cybr-hak-con-vm/ssh_key`. Reused across runs so `known_hosts` doesn't churn (we use `-o UserKnownHostsFile=/dev/null` to be safe anyway).
3. **Builds a cloud-init NoCloud seed ISO.** Contains a `user-data` file that creates a user named `agent` with passwordless sudo and the SSH public key authorized. Cloud-init reads this on first boot.
4. **Creates a qcow2 overlay** backed by the cached cloud image. The VM's writes go to the overlay, not the image. Wipe the overlay and you're back to a clean state.
5. **Boots qemu** with KVM if available, TCG otherwise. User-mode networking with port forward `localhost:2222 -> guest:22`.
6. **Waits for SSH** with a 3-minute timeout. Most first boots take 30-60 seconds; subsequent boots are faster.
7. **Runs the probes** via `ssh`/`scp`, then shuts the VM down (graceful via `sudo poweroff` first, force-kill if that fails).

## KVM versus TCG

If `/dev/kvm` is readable, the script uses `-enable-kvm -cpu host`. That gives near-native CPU performance and ~30-second boots.

If `/dev/kvm` isn't available (uncommon on bare-metal Linux but possible inside cloud VMs that don't expose nested virt), qemu falls back to TCG software emulation. Boots take ~2-3 minutes and CPU work inside the VM is much slower.

To check whether KVM works on your machine:

```sh
ls -l /dev/kvm
# crw-rw---- 1 root kvm  10, 232 ... /dev/kvm  -- group access
# OR
# crw-rw-rw- 1 root root 10, 232 ... /dev/kvm  -- world access
```

You typically need to be in the `kvm` group (or root) to use it. On most distros: `sudo usermod -aG kvm $USER`, then log out and back in.

## Why the cloud-init seed?

Cloud-init is the standard way to provision a cloud VM at first boot. The `NoCloud` data source it uses lets you present `user-data` and `meta-data` as a small ISO that the VM mounts as a CD-ROM. Cloud-init reads them, applies the configuration, and never runs again unless you change the seed.

For the workshop, the seed creates a single user (`agent`) with the cached SSH key authorized and `NOPASSWD:ALL` sudo. That's enough for the probes to run and for the script to copy files in.

If you want to extend the seed (install packages, add files, run scripts), edit the heredoc in `launch-and-probe.sh`. The cloud-init docs at https://cloudinit.readthedocs.io/ list every available module.

## Disk usage

After running the workshop, your `~/.cache/cybr-hak-con-vm/` will contain:

- The base image (~600 MB, kept across runs)
- The overlay disk (~50-200 MB, depends on what was written; refreshed each run)
- The userdata seed ISO (~6 KB)
- The SSH keypair (~1 KB)
- The qemu PID file (transient)

`bash cleanup.sh` removes the overlay disk only. `bash cleanup.sh --full` removes everything including the base image.

## Common gotchas

- **`KVM_ARGS=()` and bash 4+.** The launch script uses bash arrays. If you're on an ancient bash 3 (e.g., default macOS bash), the array syntax will error. Mac users should use the platform-specific version (Lima-based) when it's built.
- **`cloud-localds` not installed.** It's in `cloud-utils` (Debian/Ubuntu: `apt install cloud-image-utils`; Arch: `pacman -S cloud-image-utils`; NixOS: `nix shell nixpkgs#cloud-utils`). The script checks for it up front.
- **Image download fails.** First run needs internet. The Ubuntu cloud-image mirror is reliable but if it's unreachable, retry or pre-fetch manually.
- **SSH never becomes reachable.** Most often: cloud-init failed to apply the user-data, usually because the seed ISO is malformed. Inspect the VM by adding `-display gtk` to the qemu command and watching the boot.
- **Overlapping ports.** If localhost:2222 is in use (another VM, a tunnel, etc.), edit `SSH_PORT=2222` near the top of the script.
- **Stale qemu processes.** If a previous run died without cleanup, `bash cleanup.sh` clears them. The launch script also detects and kills stale processes from `qemu.pid`.

## Customizing the VM

If you want to change RAM, CPU, or the user-data:

- Memory: `-m 1G` -> `-m 4G` for heavier work.
- CPUs: `-smp 2` -> `-smp 4`.
- User-data: edit the heredoc in `launch-and-probe.sh`. Add `packages: [...]` to install on first boot (will slow boot if you add many).

For more substantial customization (different base image, extra disks, networking changes), the script is short enough that copying it as a starting point and modifying is reasonable.
