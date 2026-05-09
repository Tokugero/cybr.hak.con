# Other platforms

This workshop is implemented for Linux only. Most of it is platform-agnostic — gluetun and the compose stack run as Linux containers regardless of host, and Docker Desktop on Mac/Windows transparently runs everything inside a Linux VM. What differs is the host-side runner script. Ask your agent to translate `linux/` into your platform.

## Mac equivalents

- Docker Desktop (or Podman Desktop / OrbStack / Colima). The compose file works unchanged.
- Host-side `run-baseline.sh` and `run-via-sidecar.sh` translate to `bash` on macOS with no real changes. `realpath` differs slightly between BSD and GNU; if you use it, verify behavior.

## Windows equivalents

- Docker Desktop with the WSL 2 backend. The compose file works unchanged.
- Host-side scripts become `.ps1`. Bind-mount paths use Windows syntax (`${PWD}` or absolute); Docker Desktop translates them.

## Gotchas your agent won't infer

- **Line endings.** `egress-probe.sh` is mounted into the worker container as bash; CRLF will break it. Set `core.autocrlf input` on this repo or `dos2unix` the script before mounting.
- **`/dev/net/tun` exists inside Docker Desktop's Linux VM**, which is what makes gluetun work on Mac/Windows at all. Don't let your agent "helpfully" remove the `devices:` block from the compose file.
- **The fail-closed demonstration looks identical on every platform** — gluetun fails to authenticate, the worker has no network, every probe row reads `fail`. That's the point; don't let your agent paper over it with a fall-through to direct networking.

## Asking your agent

A starting prompt:

> Translate `linux/run-baseline.sh` and `linux/run-via-sidecar.sh` into `<mac|windows>/` equivalents. The Dockerfile, compose file, .env.example, and egress-probe.sh are platform-agnostic — copy them unchanged. For Windows, use PowerShell and `${PWD}` for the bind-mount path. Preserve the fail-closed semantics: with no VPN credentials, all probe rows must read `fail`.

See `discussion.md` for the full prompt scaffold.
