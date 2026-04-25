# Porting container-isolation to Mac and Windows

This is a handoff doc. The `linux/` folder has the verified, working version of the workshop. Mac and Windows aren't built yet. This file tells a future agent (or anyone with access to those platforms) exactly what to create and what to expect.

The good news: the *container side* of the workshop is platform-agnostic. The probe runs inside a Linux container in every case. What differs between platforms is (1) the host-side launch script (sh vs PowerShell), and (2) where the Linux container actually executes (Linux native vs the Linux VM that Docker Desktop runs on Mac/Windows).

## The Mac/Windows-as-Linux-VM caveat

This is also material content, not just a porting note: on Mac and Windows, Docker Desktop runs all containers inside a Linux VM. So when the workshop says "container," you're really running container-in-a-VM. The container-side security model is identical; the kernel that's "shared" is the VM's kernel, not your host's. Different threat model than Linux native, and worth saying explicitly in `mac/notes.md` and `windows/notes.md`.

## Mac scaffold

### Files to create at `topics/sandboxing/container-isolation/mac/`

| File | Source | What changes |
|------|--------|--------------|
| `container-probe.sh` | direct copy of `../linux/container-probe.sh` | None. Runs inside the (Linux) container regardless of host platform. |
| `run-default.sh` | mostly direct copy | Confirm `id -u` returns the Mac UID (it does). The path-resolution math at the top should still work; verify with `realpath` if available. |
| `run-hardened.sh` | mostly direct copy | Same as above. |
| `notes.md` | rewrite | Mac-specific Docker Desktop setup (download from docker.com, enable Rosetta if on Apple Silicon and pulling x86 images), plus the "you're container-in-a-VM" callout. |
| `tests/run.sh` | direct copy | Should work as-is on Mac. |

### Mac-specific notes for `notes.md`

- Install Docker Desktop from https://www.docker.com/products/docker-desktop/.
- On Apple Silicon Macs, Docker Desktop runs an arm64 Linux VM by default. `ubuntu:24.04` has both arm64 and amd64 manifests, so it pulls the arm64 variant automatically.
- The container probe will report `container | yes` (via `/.dockerenv`), but the `pid 1` will look the same as Linux native — that's because you're inside the Linux VM's container, not directly on macOS.
- `id -u` returns your Mac UID, which gets passed into the container. The container will use that uid even though there's no matching `/etc/passwd` entry; that's expected.

### Verification checklist (Mac)

- [ ] `docker info` works and reports a server version
- [ ] `bash mac/run-default.sh` runs cleanly and reports `uid 0` inside the container
- [ ] `bash mac/run-hardened.sh` runs cleanly and reports `uid $(id -u)` (your Mac UID)
- [ ] `bash mac/tests/run.sh` exits 0 with `PASS`

---

## Windows scaffold

### Files to create at `topics/sandboxing/container-isolation/windows/`

| File | Source | What changes |
|------|--------|--------------|
| `container-probe.sh` | direct copy of `../linux/container-probe.sh` | None. Runs inside the (Linux) container regardless of host platform. |
| `run-default.ps1` | rewrite from `../linux/run-default.sh` | PowerShell port. The bind-mount path syntax differs: use `${PWD}` or absolute paths; Docker Desktop translates Windows paths automatically. |
| `run-hardened.ps1` | rewrite from `../linux/run-hardened.sh` | PowerShell port. `id -u`/`id -g` aren't available; you'll need to handle the `--user` flag differently. See "Windows-specific gotchas" below. |
| `notes.md` | rewrite | Windows-specific Docker Desktop setup, WSL backend caveat, the path-translation behavior of `-v`. |
| `tests/run.ps1` | rewrite from `../linux/tests/run.sh` | PowerShell port. |

### Windows-specific notes for `notes.md`

- Install Docker Desktop from https://www.docker.com/products/docker-desktop/. The default backend on modern Windows is WSL 2.
- `id -u` and `id -g` aren't available in PowerShell. Two paths for the `--user` flag:
  1. **Skip `--user` entirely** and rely on rootless Docker (configurable in Docker Desktop settings) or accept that the hardened container still runs as root. Document this clearly.
  2. **Use `1000:1000`** as a fixed non-root uid/gid, which is the default for many Linux base images.
  Both have trade-offs; the workshop should pick one and explain why.
- Bind-mount paths use Windows-style paths (`C:\...` or `${PWD}`); Docker Desktop translates them to the Linux VM internally.
- WSL 2 backend means the "container kernel" is actually WSL's kernel, which is itself a Linux VM. That's two layers of VM-ish-ness.

### Windows-specific gotchas

- `Test-Path` returns boolean; use `if (Test-Path ...)` directly.
- The `--security-opt=no-new-privileges` flag is `--security-opt=no-new-privileges:true` in some Docker versions; check your version.
- File line endings: Windows defaults to CRLF, which can break bash scripts mounted into the container. Use `git config core.autocrlf input` for this repo, or `dos2unix` the scripts before mounting.

### Verification checklist (Windows)

- [ ] `docker info` works in PowerShell and reports a server version
- [ ] `pwsh windows/run-default.ps1` runs cleanly and reports `uid 0` inside the container
- [ ] `pwsh windows/run-hardened.ps1` runs cleanly with whatever uid you chose for the host user mapping
- [ ] `pwsh windows/tests/run.ps1` exits 0 with `PASS`

---

## Once each platform is built and verified

1. Update `README.md` in this topic — change "(coming soon)" or the Linux-only layout to reflect the new platforms.
2. Add a row to the table in `REQUIREMENTS.md` if any tooling differs (it shouldn't — Docker is Docker).
3. Commit with `feat(sandboxing): add <platform> port for container-isolation`.

If you find that one of the Linux-side files needed adjustments to be portable, lift those adjustments back into the Linux file too so all platforms stay aligned. Cross-platform parity is the point.
