# Linux notes

Platform-specific notes for the Linux composition workshop.

## What "Tier 0 always at the base" means in practice

Every example runner in `linux/` assumes the host shell that launched it has cred-scrub + direnv-perimeter applied. The runners do *not* re-scrub on their own. Here's what that looks like operationally:

```sh
# One-time setup
mkdir -p ~/sandbox-test
cp <repo>/topics/sandboxing/cred-scrub/linux/solution.envrc ~/sandbox-test/.envrc
cd ~/sandbox-test
direnv allow

# Now any runner you launch from this shell inherits the scrubbed env
bash <repo>/topics/sandboxing/composition/linux/compose-bwrap.sh
bash <repo>/topics/sandboxing/composition/linux/compose-docker.sh
bash <repo>/topics/sandboxing/composition/linux/compose-docker-egress.sh
```

If you run a composition from outside the perimeter, the inner sandbox layers still apply but the host shell isn't scrubbed — the agent's parent process has whatever your launching shell had. That's a meaningfully different threat profile from the matrix in `workshop.md`.

## Why each demo runner just delegates

The three demo runners (`compose-bwrap.sh`, `compose-docker.sh`, `compose-docker-egress.sh`) are deliberately thin. Each prints the host's relevant Tier 0 state, then `exec`s into the underlying topic's runner against the cred-scrub probe. They're for *seeing* what each composition does to a known workload.

For real work, see `run-stacked.sh` in the same directory: it takes a `--target` directory and an optional `-- command` and applies the Tier 0 check plus your chosen Tier 1 or Tier 2 hardening. It's parameterized, ~150 lines, and meant to be copied and adapted rather than used as a black box. The exercise after working through `discussion.md` is to fork it for your own workflow — change defaults, add the egress sidecar, drop in a target-directory-specific allowlist.

## How `bwrap` and Docker compositions differ in practice

Both can produce nearly identical filesystem and network isolation. The differences that matter for choosing:

- **Spin-up time.** bwrap is fork+exec — a few milliseconds. Docker is image-pull-on-first-run plus container start — seconds at minimum.
- **Daemon footprint.** Docker requires a daemon running (or rootless's user-mode daemon). bwrap requires nothing.
- **Audit cost.** Docker's flags are well-known and widely documented; auditing a `docker run` invocation is easier for newcomers. bwrap's `--bind` semantics are more flexible but require more care.
- **Persistence model.** Docker has named volumes, build caches, image layers — all places state can live across "runs." bwrap leaves nothing behind unless you bind in a writable path.
- **Cross-platform.** Docker works on Mac/Windows (with Docker Desktop). bwrap is Linux-only.

For a one-shot agent invocation against an unfamiliar repo, bwrap is usually the right choice (faster, lighter, no daemon). For a long-running MCP server or a GUI tool that needs to persist some state, Docker is usually the right choice. The composition workshop's job is to make those trade-offs explicit, not to push one over the other.

## The implicit Tier 3 on Mac/Windows

A teaching point worth knowing for the talk: on Mac/Windows, when you use Docker Desktop, your "Tier 2 container" runs inside a Linux VM that Docker Desktop spins up. So Mac/Windows users get an *implicit* Tier 3 layer for free — the kernel attack surface row in the matrix is actually closed for them, even though they think they're at Tier 2.

That's a free defense Mac/Windows users have that Linux-native users don't. It's also the reason cross-platform performance comparisons are misleading (they're really comparing hypervisor overhead, not container overhead).

## Where the cracks are between layers

Composition can fail in subtle ways at the seams between layers:

- **`-e VAR` from a non-scrubbed parent.** If your host shell isn't actually scrubbed, `docker run -e GITHUB_TOKEN` passes whatever your shell had, which might be your prod token. The container looks hardened; the credential is real-and-broad.
- **`-v` bind-mounts cross the FS boundary.** Bind-mounting `~/.aws` defeats every other layer. Read every `-v` line.
- **`network_mode: "host"`** in compose silently undoes container network isolation. Same with `--network=host` on a `docker run`.
- **`--privileged`** undoes most of the cap-drop hardening. Almost no agent workload legitimately needs it.

When evaluating someone else's composed setup, scan for these four patterns first.
