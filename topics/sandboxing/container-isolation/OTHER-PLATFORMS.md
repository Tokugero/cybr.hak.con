# Other platforms

This workshop is implemented for Linux only. The container side is platform-agnostic — the probe runs inside a Linux container regardless of host. What differs is (1) the host-side launcher (sh vs PowerShell) and (2) where the Linux container actually executes. Ask your agent to translate `linux/` into your platform using the notes below.

## Mac equivalents

- Docker Desktop, Podman Desktop, OrbStack, or Colima. All of them spin up a Linux VM in the background and run containers inside it.
- The host-side scripts (`run-default.sh`, `run-hardened.sh`) translate cleanly to `bash` on macOS — BSD vs GNU `realpath` is the only common snag.

## Windows equivalents

- Docker Desktop with the WSL 2 backend (the modern default).
- Host-side scripts become `.ps1`. `id -u` / `id -g` aren't available in PowerShell — pick a fixed non-root uid like `1000:1000` or skip `--user` and document why.

## Gotchas your agent won't infer

- **Docker Desktop is itself a Linux VM.** On Mac and Windows, "container" means container-inside-Linux-VM. The container-side model is identical, but the kernel that's "shared" is the VM's kernel, not your host's. Different threat model — call it out in the platform notes if your agent generates them.
- **Line endings matter on Windows.** CRLF will break any bash script (probe, runner) mounted into the container. Set `core.autocrlf input` on this repo, or `dos2unix` the scripts before mounting.
- **Apple Silicon pulls arm64 manifests by default.** `ubuntu:24.04` is fine; less common images may not have an arm64 variant and will silently emulate, which can mask perf issues but also occasionally exposes architecture-specific bugs.
- **`--security-opt=no-new-privileges` syntax varies.** Some Docker Desktop versions want `:true` appended; check the version your agent generated against.

## Asking your agent

A starting prompt:

> Translate `linux/run-hardened.sh` into a `<mac|windows>/` equivalent. Keep the same hardening flags (`--user`, `--read-only`, `--cap-drop=ALL`, `--security-opt=no-new-privileges`, no network unless explicitly enabled). For Windows, use PowerShell and pick a fixed uid for `--user`. Add a short note about the Docker-Desktop-is-a-VM caveat to `notes.md`.

See `discussion.md` for the full prompt scaffold.
