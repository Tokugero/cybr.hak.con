# Other platforms

This workshop is implemented for Linux only (`qemu-system-x86_64` + cloud-init). Mac and Windows have different idiomatic VM stacks — porting means picking different tools that achieve the same threat model, not translating syntax. Ask your agent to translate `linux/` into your platform using the notes below.

## The catch worth understanding before you port

Most Mac/Windows users are *already* running an implicit Tier 3 layer via Docker Desktop or WSL 2 — both products spin up a Linux VM in the background to host containers. So "I need a VM for my agent" is often already satisfied by tooling the user has installed for other reasons. This workshop stays useful when:

- You want a *disposable* VM separate from Docker Desktop's persistent one (e.g., evaluating malware-adjacent code).
- You want a non-Linux guest (a Windows VM on Mac, a Linux VM on Windows that isn't WSL).
- You want explicit control over hypervisor configuration (RAM, CPU, devices, snapshot/revert).

## Mac equivalents

- **Lima** or **Colima** — CLI tools that wrap Apple Virtualization framework or QEMU. Disposable Linux VMs in seconds. Lima is closest to the Linux workshop's UX.
- **UTM** — GUI front-end for Apple Virtualization framework, useful for non-Linux guests.
- A Lima invocation is much shorter than a raw qemu invocation because Lima handles the cloud-init / SSH plumbing for you.

## Windows equivalents

- **Windows Sandbox** — built-in, disposable by design (state evaporates on close), but Windows-guest only and the lifecycle is GUI-driven (`.wsb` config + double-click). Requires Windows Pro/Enterprise.
- **Hyper-V with a custom VHDX** — for a Linux disposable VM that isn't WSL.
- **WSL 2 with a separate distribution** — reset between uses for cheap disposability, though it shares the Hyper-V kernel with your other WSL distros.

## Gotchas your agent won't infer

- **Lima auto-mounts `$HOME` by default.** That's *opposite* to the Linux script's deliberate no-mount design. Tell your agent to disable home mounting in the Lima config — otherwise the VM has full read access to your home directory and the entire isolation goal is defeated.
- **Windows Sandbox is interactive.** A test harness can't drive it the way `linux/tests/run.sh` drives qemu over SSH. Skip the harness or have it generate a `.wsb` and stop there.
- **The implicit-Tier-3-via-Docker-Desktop point is teachable, not a bug.** Don't let your agent suppress it — it's part of the workshop's content, not a porting wart.

## Asking your agent

A starting prompt:

> Translate `linux/launch-and-probe.sh` into a `<mac|windows>/` equivalent using `<Lima | Windows Sandbox | Hyper-V>`. Preserve the disposability and no-host-mount properties — the VM should not have access to my home directory. For Lima specifically, disable the default `$HOME` mount. Read `linux/notes.md` for the security intent before generating code.

See `discussion.md` for the full prompt scaffold.
