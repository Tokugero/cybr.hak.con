# Porting composition to Mac and Windows

Handoff doc. The composition topic doesn't introduce new mechanics; it stacks the layers from the other topics. So porting it follows from porting the underlying topics.

## What needs to exist before porting

- `mac/` for cred-scrub, direnv-perimeter, container-isolation, network-egress (already partly built / scaffolded)
- `windows/` for the same (mostly scaffolded)
- `mac/` for process-isolation (not built yet — uses `sandbox-exec`)
- Windows process-isolation realistically points at WSL

If those underlying ports exist, the composition runners are just the same conceptual stack with platform-specific commands.

## Mac scaffold at `topics/sandboxing/composition/mac/`

| File | Approach |
|------|----------|
| `compose-sandbox-exec.sh` | Tier 0 + Tier 1 (sandbox-exec). Profile that allows the workshop dir, denies others. |
| `compose-docker.sh` | Direct adaptation from `linux/compose-docker.sh`. Docker Desktop equivalent. |
| `compose-docker-egress.sh` | Direct adaptation from linux. Docker Compose works on Docker Desktop. |
| `notes.md` | Mac-specific composition notes — the "Docker Desktop is itself a Linux VM" callout (which is actually a free Tier 3 layer for Mac users, an interesting quirk). |
| `tests/run.sh` | Direct adaptation. |

The interesting thing for Mac users: when you compose Tier 0 + Tier 2 (Docker), you're *implicitly* getting Tier 3 too because Docker Desktop runs in a Linux VM. So the matrix's "Kernel attack surface" row is closed for Mac/Windows users by accident, not by design. Worth flagging as a teaching point in `mac/notes.md`.

## Windows scaffold at `topics/sandboxing/composition/windows/`

| File | Approach |
|------|----------|
| `compose-docker.ps1` | PowerShell port. |
| `compose-docker-egress.ps1` | PowerShell port. |
| `notes.md` | Windows-specific. Recommends WSL2 for the bwrap layer; Docker Desktop for the others. The "implicit Tier 3 via Docker Desktop / WSL VM" callout applies here too. |
| `tests/run.ps1` | PowerShell harness. |

For the bwrap layer on Windows, the recommendation is to use WSL2 and follow the Linux folder. The composition runner script could detect WSL and dispatch.

## Verification checklist (per platform)

For each platform port:

- [ ] Each runner script in `<platform>/` runs without error
- [ ] The probe output inside each composition shows the expected isolation level
- [ ] The matrix in `workshop.md` is verifiable by running each composition and checking the probe output against the row claims
- [ ] `tests/run.sh` (or `.ps1`) exits 0 with `PASS`
