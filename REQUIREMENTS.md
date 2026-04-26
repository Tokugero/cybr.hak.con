# Tool requirements by topic

What you need to work through each topic. Everything listed is free and popular; nothing requires a paid account.

## By topic

| Topic | Required tools | Notes |
|-------|----------------|-------|
| [`topics/sandboxing/cred-scrub/`](topics/sandboxing/cred-scrub/) | shell (`bash`/`zsh` on Mac/Linux/WSL, PowerShell 7+ on Windows), `direnv` | Test harness uses plain shell — no test framework |
| [`topics/sandboxing/direnv-perimeter/`](topics/sandboxing/direnv-perimeter/) | shell, `direnv` | Builds on cred-scrub; same prerequisites |
| [`topics/sandboxing/process-isolation/`](topics/sandboxing/process-isolation/) | shell, `bubblewrap` (Linux) | Linux-only first pass; Mac uses `sandbox-exec`, Windows uses WSL or AppContainer |
| [`topics/sandboxing/container-isolation/`](topics/sandboxing/container-isolation/) | shell, `docker` | Mac/Windows: Docker Desktop runs containers in a Linux VM, which is itself a teachable point in this topic |
| [`topics/sandboxing/network-egress/`](topics/sandboxing/network-egress/) | shell, `docker`, `docker compose` v2 | Workshop body works without a VPN subscription (fail-closed demo); going-further uses gluetun + a paid VPN provider |
| [`topics/sandboxing/vm-isolation/`](topics/sandboxing/vm-isolation/) | shell, `qemu`, `cloud-utils`, KVM (Linux) | First run downloads ~600MB Ubuntu cloud image, cached |
| [`topics/sandboxing/composition/`](topics/sandboxing/composition/) | depends on which composition you run | Stacks cred-scrub + direnv-perimeter + one of process / container / network / vm |

## Install pointers

- **shell** — bash and zsh ship with Mac/Linux/WSL by default. PowerShell 7+ on Windows: `winget install Microsoft.PowerShell` or download from Microsoft.
- **direnv** — https://direnv.net/docs/installation.html. Available via every major package manager (`brew install direnv`, `apt install direnv`, `pacman -S direnv`, `scoop install direnv`, `nix-env -iA nixpkgs.direnv`).
- **bubblewrap** — Linux only. `apt install bubblewrap`, `pacman -S bubblewrap`, `dnf install bubblewrap`, or `nix shell nixpkgs#bubblewrap`. Requires user namespaces enabled in the kernel (the default on most distros).
- **Docker** — https://docs.docker.com/get-docker/. Docker Desktop on Mac/Windows; native on Linux. On Linux you may need to add yourself to the `docker` group, or run rootless — see your distribution's docs. The image used by the workshop is `ubuntu:24.04` (~30MB, pulled on first run).
- **qemu + cloud-utils** (Linux) — `apt install qemu-system-x86 cloud-image-utils`, `pacman -S qemu cloud-image-utils`, or equivalent. KVM acceleration requires `/dev/kvm` access (typically: add yourself to the `kvm` group). Used by the vm-isolation topic; first run downloads ~600MB Ubuntu cloud image, cached.

## What you can run with what you have

| You have... | Topics |
|-------------|--------|
| just a shell | (none yet — `direnv` is the floor for the sandboxing track) |
| shell + `direnv` | cred-scrub, direnv-perimeter |
| shell + `direnv` + `bubblewrap` (Linux) | + process-isolation |
| shell + `direnv` + Docker | + container-isolation, network-egress |
| shell + `direnv` + qemu + KVM (Linux) | + vm-isolation |
| any combination of the above | composition (uses whatever Tier 1+ layer you have) |

This file grows as new topics are added. If you want to know what additional tools a planned future topic will require, look at the topic's `README.md` once it exists.
