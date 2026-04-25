# Porting network-egress to Mac and Windows

Handoff doc. The `linux/` folder has the verified, working version of the workshop. Mac and Windows aren't built yet. This file tells a future agent (or anyone with access to those platforms) exactly what to create and what to expect.

The good news: the *container side* of this topic is platform-agnostic. Gluetun runs as a Linux container regardless of the host. Docker Desktop on Mac/Windows transparently runs everything inside a Linux VM, so the docker-compose stack works unchanged. What differs between platforms is (1) the host-side run scripts, and (2) some Docker Desktop quirks worth flagging.

## Mac scaffold

### Files to create at `topics/sandboxing/network-egress/mac/`

| File | Source | What changes |
|------|--------|--------------|
| `Dockerfile` | direct copy of `../linux/Dockerfile` | None. Builds a Linux image either way. |
| `docker-compose.yml` | direct copy of `../linux/docker-compose.yml` | None. Compose works identically on Docker Desktop. |
| `.env.example` | direct copy of `../linux/.env.example` | None. |
| `egress-probe.sh` | direct copy of `../linux/egress-probe.sh` | None. Runs inside the Linux container regardless of host. |
| `run-baseline.sh` | mostly direct copy | Verify `realpath` / path math works on macOS (BSD utils differ slightly from GNU). |
| `run-via-sidecar.sh` | direct copy | Should work as-is. |
| `notes.md` | rewrite | Mac-specific Docker Desktop setup; the Apple Silicon vs Intel image-pull note; the "you're a VM inside a VM inside a VPN" composition flavor. |
| `tests/run.sh` | direct copy | Should work as-is. |

### Mac-specific notes for `notes.md`

- Install Docker Desktop from https://www.docker.com/products/docker-desktop/.
- On Apple Silicon Macs, Docker Desktop runs an arm64 Linux VM. `qmcgaw/gluetun:v3` ships arm64 manifests; `ubuntu:24.04` ships arm64 manifests. Both pull the right architecture automatically.
- `/dev/net/tun` exists inside Docker Desktop's Linux VM, so the `devices` directive in compose works.
- The fail-closed demonstration looks identical: gluetun fails to authenticate, worker has no network, probe rows all read `fail`.

### Verification checklist (Mac)

- [ ] `docker info` and `docker compose version` work in Terminal
- [ ] `bash mac/run-baseline.sh` runs and reports egress reachable
- [ ] `bash mac/run-via-sidecar.sh` runs and reports egress all-fail (no VPN credentials)
- [ ] `bash mac/tests/run.sh` exits 0 with `PASS`

---

## Windows scaffold

### Files to create at `topics/sandboxing/network-egress/windows/`

| File | Source | What changes |
|------|--------|--------------|
| `Dockerfile` | direct copy of `../linux/Dockerfile` | None. |
| `docker-compose.yml` | direct copy of `../linux/docker-compose.yml` | None. |
| `.env.example` | direct copy of `../linux/.env.example` | None. |
| `egress-probe.sh` | direct copy of `../linux/egress-probe.sh` | None — runs inside the Linux worker container. |
| `run-baseline.ps1` | rewrite from `../linux/run-baseline.sh` | PowerShell port. The bind-mount path is host-style on Docker Desktop; use `${PWD}` or absolute paths. |
| `run-via-sidecar.ps1` | rewrite | Same path-translation caveat; also check `docker compose exec -T` behavior on Windows. |
| `notes.md` | rewrite | WSL 2 backend note, line-ending caveat (`core.autocrlf input` for the repo or `dos2unix` the bash scripts). |
| `tests/run.ps1` | rewrite | PowerShell port; reuse the child-pwsh-process pattern from `../../cred-scrub/windows/tests/run.ps1` for env isolation. |

### Windows-specific notes for `notes.md`

- Install Docker Desktop from https://www.docker.com/products/docker-desktop/. The default backend on modern Windows is WSL 2.
- File line endings: the `egress-probe.sh` and bash run scripts must have LF line endings. Set `core.autocrlf input` in this repo, or `dos2unix` the scripts before mounting.
- The compose file's `volumes: ../../:/workshop:ro` works because Docker Desktop translates Windows paths automatically.
- `/dev/net/tun` exists inside the WSL 2 VM, so gluetun works.

### Verification checklist (Windows)

- [ ] `docker info` and `docker compose version` work in PowerShell
- [ ] `pwsh windows/run-baseline.ps1` runs and reports egress reachable
- [ ] `pwsh windows/run-via-sidecar.ps1` runs and reports egress all-fail (no VPN credentials)
- [ ] `pwsh windows/tests/run.ps1` exits 0 with `PASS`

---

## Once each platform is built and verified

1. Update `README.md` in this topic to reflect the new platforms in the layout.
2. Commit with `feat(sandboxing): add <platform> port for network-egress`.

If a Linux-side file needs adjustments to be portable, lift those adjustments back into the Linux file too. Cross-platform parity is the point.
