# Linux notes

Platform-specific notes for the Linux container-isolation workshop.

## Docker setup recap

If Docker isn't installed yet:

- **Debian / Ubuntu:** follow the official instructions at https://docs.docker.com/engine/install/, *not* `apt install docker.io` (which is often outdated).
- **Arch:** `pacman -S docker docker-buildx`, then `systemctl enable --now docker`.
- **NixOS / Nix:** `services.docker.enable = true;` in your config.

After install, you'll need either:

- To add yourself to the `docker` group (`sudo usermod -aG docker $USER`, then log out and back in), **or**
- To use rootless Docker (https://docs.docker.com/engine/security/rootless/) which avoids granting your user host-equivalent privileges via group membership.

The workshop scripts work either way.

## What the probe checks for

The container shape probe answers a small set of practical questions:

- **`uid`/`gid`** — am I root in this container? (Default Docker says yes.)
- **`/.dockerenv`** — quick boolean for "is this Docker?". Not present in podman containers; the cgroup hint catches those.
- **PID 1** — what's running as the container's init? Useful for spotting tini, dumb-init, or your own bash.
- **`CapEff`** — the effective capability set. The probe reports it as a hex string; `0000000000000000` means all dropped.
- **Network namespace** — counts routes in `/proc/self/net/route`. Zero means `--network=none` worked.
- **Root filesystem writability** — tries to `touch /.write-test`. Fails fast if `--read-only`.
- **Docker socket** — checks for `/var/run/docker.sock`. Mounted: bad. Absent: good.
- **`/tmp` writability** — sanity check for the `--tmpfs /tmp` flag.

## Common gotchas

- **First run pulls the image.** `docker pull ubuntu:24.04` takes 10–30 seconds depending on your bandwidth. Subsequent runs use the cached layer.
- **No internet, can't pull.** If you're offline and don't have `ubuntu:24.04` cached, the run scripts will fail. Pre-pull when you have connectivity.
- **`--user=$(id -u):$(id -g)` and missing /etc/passwd entries.** Setting an arbitrary uid that doesn't exist in the container's `/etc/passwd` is fine for processes — they just show as "I have no name!" in some commands. The probes handle this gracefully.
- **`--read-only` and bash startup files.** Some container images expect to write to `/root/.bash_history` or `/etc/bash_completion.d/` on startup. `ubuntu:24.04` is generally well-behaved with `--read-only` because we run a single bash command; longer-lived sessions may complain.
- **`--network=none` and DNS.** No network means no DNS. Tools that need to do *any* network operation will fail. That's the point — but if your test fails with "could not resolve," it's the network flag working, not a bug.
- **Mac/Windows Docker Desktop.** Not Linux native — Docker Desktop runs containers inside a Linux VM. The container security model is identical; the kernel that's "shared" is the VM's, not your host's. Worth knowing for threat-model conversations.

## Debugging

If a run script fails, the most likely causes (in order):

1. Docker daemon not reachable. Try `docker info` outside the workshop. If that fails too, fix Docker first.
2. No internet to pull the image. `docker pull ubuntu:24.04` manually to confirm.
3. Permission issues. If you see `permission denied` on the docker socket, you're not in the `docker` group (or rootless isn't set up). See "Docker setup recap" above.
4. Bind-mount path doesn't exist. The script computes the sandboxing dir from its own location; if you've moved files around, check the path math at the top of each `run-*.sh`.
