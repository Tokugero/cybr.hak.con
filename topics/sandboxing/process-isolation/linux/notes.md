# Linux notes

Platform-specific notes for the Linux process-isolation workshop.

## Why bubblewrap

`bwrap` is the closest thing Linux has to a "wrap a single command in a sandbox" tool. It's used by Flatpak, GNOME, and others. Three properties matter for an agent workflow:

- **Setuid root, drops privs immediately.** `bwrap` is installed setuid so it can call `unshare()` for namespaces and `pivot_root()` for the new mount tree. Once that's done, it drops to your uid before exec-ing your command. The sandboxed process is your user, just inside its own namespaces.
- **Capabilities dropped by default.** The bounding set is empty after bwrap exec-s. Even if your shell has `CAP_NET_RAW` (you don't, normally), the bwrap'd process won't.
- **Pure setup, no daemon.** Once `bwrap exec`s, there's no bwrap process hanging around. No socket, no daemon, no per-host configuration. The lifecycle is entirely the wrapped command's lifecycle.

## What `--unshare-*` flags do

Each `--unshare-*` flag creates a new Linux namespace of that type. In rough order of impact for an agent context:

- `--unshare-net` — new network namespace. The sandbox has its own loopback and nothing else. No internet, no DNS, no Docker socket reachable. You probably want this for untrusted agent work.
- `--unshare-pid` — new PID namespace. The sandbox sees only its own processes. PID 1 inside is whatever you exec'd. The sandbox can't `kill` host processes (they don't exist in its view).
- `--unshare-uts` — new UTS namespace. The sandbox can change its own hostname without affecting the host.
- `--unshare-ipc` — new IPC namespace. SysV semaphores, message queues, shared memory are isolated.
- `--unshare-cgroup` — new cgroup namespace. The sandbox sees its own cgroup root.
- `--unshare-user` — new user namespace. The sandbox sees its own UID 0 (root in the namespace, which maps to your real UID outside). This is more powerful than the others — without it, bwrap would need root to do everything else, but with it, an unprivileged user can run bwrap. The hardened script in this workshop *deliberately doesn't* use this flag because it changes how `id`, `chown`, and others behave inside, which can confuse probes and tools.

`--unshare-all` enables all six. That's the strongest option, but the user-namespace caveat above applies.

## NixOS path notes

On NixOS, `/usr` is mostly empty and binaries live in `/nix/store/...`. The hardened script handles this by binding `/nix/store` (read-only) when it exists. The same script works on standard distros because they don't have `/nix/store` and the loop just skips it.

If you're on NixOS and the hardened bwrap fails to find `bash` or other commands, check that `/nix/store` is bound and that `/run/current-system` (which has profile symlinks) is also bound — both are in the script's bind list.

## Bwrap and capabilities

By default, `bwrap` clears the bounding set. To prove this, run inside the hardened bwrap:

```sh
grep CapBnd /proc/self/status
```

You should see `CapBnd: 0000000000000000`. That's the bounding set, which limits what capabilities any process in this hierarchy can ever acquire. With it empty, no process inside the bwrap can `setuid`-into root and gain capabilities.

## Common gotchas

- **User namespaces disabled.** Some hardened distros (older Debian, RHEL with specific configs) disable user namespaces for unprivileged users. Test with `unshare -U /bin/true` — if that fails, bwrap will too.
- **Setuid bwrap blocked.** Some sandboxed runtimes (other containers, some snap/flatpak setups) block setuid execution. Bwrap won't work there. The error message is usually clear ("permission denied").
- **Bind path doesn't exist on host.** `--ro-bind /lib /lib` fails if your distro doesn't have a top-level `/lib` (e.g., NixOS, where `/lib` is just a symlink). The hardened script's `for dir in ...; do [ -e "$dir" ] && ...; done` loop handles this.
- **`--unshare-user` and `id`.** Inside a user-namespaced bwrap, `id` reports uid 0 (root in the sandbox). That's not a security issue — outside, you're still your real user — but it can confuse scripts that branch on `id -u`. The hardened script avoids this by not using `--unshare-user`.
- **`/dev/null` and other devices.** `--dev /dev` mounts a fresh devtmpfs with only the standard subset (null, zero, full, random, urandom, tty). If you need GPU devices or audio, you have to `--dev-bind` them explicitly, which re-exposes the host devices.

## Debugging bwrap

If a bwrap invocation fails with a confusing error:

- Add `--bind /tmp /tmp` and try again — sometimes the missing tmpfs is the issue.
- Try the same command without `--unshare-*` flags to isolate which namespace is the problem.
- `strace -f bwrap ...` shows every syscall; the `mount` and `pivot_root` calls are usually where it fails.
- `bwrap --version` confirms the binary is recent (0.6+ has most of the flags this workshop uses).
