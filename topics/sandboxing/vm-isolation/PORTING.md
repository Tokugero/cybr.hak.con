# Porting vm-isolation to Mac and Windows

Handoff doc. The Linux topic uses `qemu-system-x86_64` directly. Mac and Windows have different idiomatic VM stacks; this is a topic where porting means *picking different tools that achieve the same threat model*, not just translating syntax.

## The big-picture for Mac/Windows users

Most Mac/Windows users are already running an implicit Tier 3 layer via Docker Desktop or WSL2 — those products spin up a Linux VM in the background to run containers. So the "I need a VM" use case for those users is often *already met* by their existing tooling.

Where this topic stays useful for Mac/Windows users:

- When they want a *disposable* VM separate from Docker Desktop's persistent one (e.g., evaluating malware-adjacent code).
- When they want a non-Linux guest (a Windows VM on Mac, a Linux VM on Windows that's *not* WSL).
- When they want explicit control over the hypervisor configuration (RAM, CPU, devices, snapshot/revert).

For the first case (disposable VM), the natural tools are:

- **Mac:** Lima or Colima (CLI tools that wrap Apple Virtualization framework or QEMU). Both spin up disposable Linux VMs in seconds. Or `vagrant`, but it's heavier.
- **Windows:** Windows Sandbox is built-in and disposable by design (state evaporates on close). Or Hyper-V with a custom VHDX.

## Mac scaffold at `topics/sandboxing/vm-isolation/mac/`

| File | Approach |
|------|----------|
| `launch-via-lima.sh` | Boots a Lima Linux VM, copies probes in, runs them, shuts down. Lima handles the cloud-init bits internally. |
| `notes.md` | Mac-specific: choosing between Lima/Colima/UTM, the implicit Tier 3 from Docker Desktop, when to reach for an explicit VM anyway. |
| `tests/run.sh` | Skips by default unless `RUN_VM_HARNESS=1` and Lima is installed. |

A Lima invocation is much shorter than a raw qemu invocation:

```sh
limactl start --name=agent template://default
limactl shell agent bash /workshop/cred-scrub/linux/probe.sh
limactl stop agent
limactl delete agent
```

That's because Lima handles the qemu/cloud-init/SSH plumbing for you.

## Windows scaffold at `topics/sandboxing/vm-isolation/windows/`

| File | Approach |
|------|----------|
| `launch-windows-sandbox.ps1` | Generates a `.wsb` config and launches Windows Sandbox. Windows Sandbox is single-shot — closes when you close the window. |
| `notes.md` | Windows-specific: Windows Sandbox vs Hyper-V vs WSL2, the licensing constraints (Windows Sandbox needs Windows Pro/Enterprise). |
| `tests/run.ps1` | Skips by default; running a real Windows Sandbox session is interactive and not test-harness-friendly. |

Windows Sandbox is the closest match to "disposable VM" for Windows users. It boots in seconds, has its own kernel, evaporates on close. Trade-off: limited to Windows guests (not Linux), and the lifecycle is GUI-driven rather than scriptable in the same way.

For a Linux disposable VM on Windows, the recommendation is **WSL2 + a separate WSL distribution** that's reset between uses, or **Hyper-V with a custom VHDX**. Both are documented in `notes.md` for users who need it.

## Verification checklists

### Mac (with Lima)

- [ ] `brew install lima` (or `nix-env -iA nixpkgs.lima`)
- [ ] `limactl start --name=agent` succeeds
- [ ] `bash mac/launch-via-lima.sh` boots, runs probes, shuts down
- [ ] `mac/tests/run.sh` exits 0 (skipped) or PASS (when `RUN_VM_HARNESS=1`)

### Windows

- [ ] Windows Sandbox feature enabled (Windows Pro/Enterprise; "Turn Windows features on or off" -> Windows Sandbox)
- [ ] `pwsh windows/launch-windows-sandbox.ps1` generates a valid `.wsb` and opens it
- [ ] Inside the sandbox, the participant can run the workshop's probes
- [ ] `windows/tests/run.ps1` exits 0 (skipped by default; the sandbox flow is interactive)

## Once each platform is built and verified

1. Update `README.md` to reflect available platforms.
2. The "implicit Tier 3 via Docker Desktop / WSL2" callout in `workshop.md` §6 is already platform-neutral; no rewrite needed.

If a Mac/Windows tool's behavior is meaningfully different from the Linux qemu version (e.g., Lima's auto-mounting of `$HOME` is *opposite* to the Linux script's no-mount design), call that out as a teaching point in the platform notes.
