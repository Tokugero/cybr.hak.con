# Workshop: process-level isolation

Hands-on. You'll wrap the cred-scrub probe in two different `bwrap` invocations — one permissive, one hardened — and compare what each reveals about your home directory.

## 1. What `bwrap` actually does

`bubblewrap` (`bwrap`) is a setuid-root utility that creates a new mount namespace, binds host paths into it according to your flags, optionally unshares other namespaces (`--unshare-pid`, `--unshare-net`, `--unshare-uts`, ...), drops most Linux capabilities by default, then `exec`s your command inside.

Three things to internalize:

- **You explicitly choose what's bound.** Nothing is in the sandbox by default. Even `/bin` isn't there unless you `--ro-bind` it. That's the opposite of Docker, where the image gives you a starting view and `-v` adds to it.
- **Namespaces are `--unshare-*` opt-in.** If you don't `--unshare-net`, you share the host's network. Same for PID, UTS, IPC, cgroup, user.
- **It's a wrapper around `exec`.** No daemon, no image, no per-command overhead. `bwrap ... bash` runs as fast as plain `bash` plus the kernel namespace setup.

## 2. Run the cred-scrub probe on the host (baseline)

```sh
bash <repo>/topics/sandboxing/cred-scrub/linux/probe.sh
```

Save the output. You'll see your real environment — env vars (whatever your shell has), dotfiles (`~/.aws`, `~/.kube`, etc. probably show as `present`), agents (SSH agent active if you have one running).

## 3. Run the probe inside a *permissive* bwrap

```sh
bash <repo>/topics/sandboxing/process-isolation/linux/bwrap-permissive.sh
```

This invokes `bwrap` with `--bind / /` (the entire host filesystem read-write), `--dev-bind /dev /dev`, `--proc /proc`, and no `--unshare-*` flags. Effectively: a wrapper around bash that does almost nothing.

Compare the probe output to step 2. It should look nearly identical — dotfiles still present, env vars still set, network still reachable. The lesson is: **bwrap with the wrong flags is just bash with extra steps.** Isolation is what *you* configure, not what bwrap gives you for free.

This is the failure mode worth demonstrating. People sometimes run `bwrap` thinking it auto-isolates and don't realize they had to opt-in.

## 4. Run the probe inside a *hardened* bwrap

```sh
bash <repo>/topics/sandboxing/process-isolation/linux/bwrap-hardened.sh
```

This invokes `bwrap` with:

- `--ro-bind` the standard read-only paths (`/usr`, `/lib`, `/lib64`, `/bin`, `/sbin`, `/etc`, plus `/nix/store` if it exists for NixOS)
- `--ro-bind <repo>/topics/sandboxing /workshop` so the probe is reachable inside the sandbox
- `--proc /proc`, `--dev /dev`, `--tmpfs /tmp`
- `--setenv HOME /tmp` so HOME points at the writable tmpfs, not a non-existent path
- `--unshare-pid --unshare-uts --unshare-ipc --unshare-cgroup` (everything except user and net)
- `--die-with-parent` so the sandbox dies if the launching shell does

Compare the probe output to steps 2 and 3:

- **Dotfile rows go from `present` to `clean`** — `~/.aws`, `~/.kube`, `~/.ssh` aren't bound in. The probe doesn't find them.
- **SSH agent goes from `active` to `clean`** — `SSH_AUTH_SOCK` either isn't inherited or points at a path the sandbox can't reach.
- **GPG agent goes from `active` to whatever** — depends on whether the agent's socket is in a path that bwrap bound (often not).

That's the fair Tier 1 demonstration. The agent process inside the sandbox literally cannot see your dotfiles because they aren't mounted into its namespace. That's a different defense than cred-scrub's "the env var isn't set" — this is "the file isn't reachable."

## 5. Compose with Tier 0

The natural composition: scrub the host shell with cred-scrub's `.envrc`, then bwrap the agent's command with the hardened binds. The shell scrub handles env vars; the bwrap handles filesystem reach.

```sh
# In a directory with cred-scrub's .envrc loaded:
cd ~/scrubbed-project

# Wrap a single command in a hardened bwrap:
bash <repo>/topics/sandboxing/process-isolation/linux/bwrap-hardened.sh \
  -- bash -c 'do-the-thing'
```

The agent inside the bwrap inherits the scrubbed shell environment (because `bwrap` copies env by default unless you `--clearenv`), so the env-var side is also clean.

## 6. The honest gaps

- **Kernel attack surface.** Same as Tier 2 — bwrap shares the host kernel. A kernel CVE that escapes namespaces escapes bwrap.
- **What you bind, you expose.** Adding `--bind $HOME $HOME` re-exposes everything. Adding `--ro-bind /var/run/docker.sock` re-exposes the Docker control plane. Read every flag.
- **`--share-net` keeps host network reachable.** Without `--unshare-net`, the sandboxed process has the same network access as the host. You probably want `--unshare-net` for an agent doing untrusted work — but then you also lose access to legitimate destinations until you compose with a network-egress strategy.
- **User namespace gotchas.** This workshop's hardened example doesn't `--unshare-user` because that creates a new uid mapping that some tools dislike. You can add it for tighter isolation; just be ready for `id` and `chown` to behave differently inside.
- **No GUI by default.** If your agent uses a GUI tool, you'd have to bind X11/Wayland sockets. That re-exposes a meaningful boundary (see the `claucker` example in the survey doc).

## 7. Where to next

`discussion.md` has prompts:

- "Walk me through writing a `bwrap` invocation that gives me only `~/sandbox-test` as a writable directory and nothing else from my home."
- "Compare `bwrap` against `firejail` — what does each do that the other doesn't?"
- "What's a single `--share-*` or `--bind` flag that, if I forgot to remove it, would defeat most of the hardening?"

The composition workshop (when it lands) walks through using cred-scrub + direnv-perimeter + container-isolation + network-egress + this together for one concrete scenario.
