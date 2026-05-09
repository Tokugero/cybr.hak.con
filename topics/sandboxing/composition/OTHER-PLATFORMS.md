# Other platforms

This workshop is implemented for Linux only. It doesn't introduce new mechanisms — it stacks layers from the other topics — so porting follows from the per-topic stubs. Read those first; this file just notes the composition-level differences.

## Per-layer pointers

- **Tier 0 (cred-scrub, direnv-perimeter)** — direnv works the same on all three platforms; see `../cred-scrub/OTHER-PLATFORMS.md` and `../direnv-perimeter/OTHER-PLATFORMS.md`.
- **Tier 1 (process-isolation)** — Mac uses `sandbox-exec`, Windows realistically uses WSL 2 (no clean native equivalent). See `../process-isolation/OTHER-PLATFORMS.md`.
- **Tier 2 (container-isolation, network-egress)** — Docker Desktop on both Mac and Windows. See `../container-isolation/OTHER-PLATFORMS.md` and `../network-egress/OTHER-PLATFORMS.md`.
- **Tier 3 (vm-isolation)** — Lima on Mac, Windows Sandbox / Hyper-V on Windows. See `../vm-isolation/OTHER-PLATFORMS.md`.

## The composition-level gotcha worth understanding

On Mac and Windows, **Tier 2 implicitly gives you Tier 3** because Docker Desktop runs all containers inside a Linux VM. So a Tier 0 + Tier 2 composition on those platforms closes the matrix's "kernel attack surface" row by accident, not by design. The trust boundary just moves to Docker Desktop's hypervisor — it doesn't disappear.

This is teachable, not a wart. If your agent generates platform-specific composition runners, tell it to keep the callout in the platform notes — it's the most interesting thing about composition on Mac/Windows.

## Asking your agent

A starting prompt:

> Translate `linux/compose-docker.sh` and `linux/compose-docker-egress.sh` into `<mac|windows>/` equivalents. The bwrap composition (`compose-bwrap.sh`) doesn't have a clean port — for Windows, recommend WSL 2; for Mac, sandbox-exec is possible but a separate exercise. Preserve the matrix in `workshop.md`; add a `notes.md` callout that Tier 2 implicitly gives Tier 3 on this platform via Docker Desktop's Linux VM.

See `discussion.md` for the full prompt scaffold.
