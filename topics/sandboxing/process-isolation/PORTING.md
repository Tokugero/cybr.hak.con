# Porting process-isolation to Mac and Windows

Handoff doc. Linux uses `bubblewrap`; Mac and Windows have entirely different process-isolation primitives. This is the most platform-divergent topic in the sandboxing track — the *concept* (Tier 1 process isolation) carries over, but the implementation is a full rewrite per platform.

## Mac scaffold

### `sandbox-exec`

macOS ships a binary called `sandbox-exec` that wraps a process in a sandbox profile written in a Scheme-like DSL. It's officially deprecated for app developers but still functional and widely used in tooling (it's how Homebrew's build sandbox works, for instance). Apple's preferred replacement for app developers is the App Sandbox / entitlements model, which doesn't apply cleanly to "wrap an arbitrary command."

### Files to create at `topics/sandboxing/process-isolation/mac/`

| File | Approach |
|------|----------|
| `sandbox-permissive.sh` | `sandbox-exec -p '(version 1)(allow default)' command` — allows everything; the equivalent of bwrap with `--bind / /`. |
| `sandbox-hardened.sh` | A profile that allows specific filesystem reads (the workshop dir, system libs), denies network if desired, denies all other file access. |
| `profile-permissive.sb` | The Scheme-like profile file for the permissive case. |
| `profile-hardened.sb` | The hardened profile. |
| `notes.md` | Mac-specific: the deprecated-but-functional caveat, how to debug profile parse errors, why this isn't quite 1:1 with bwrap's bind model. |
| `tests/run.sh` | Reuses the cred-scrub probe; checks dotfile rows go from `present` to `clean`. |

### Honest framing for mac/notes.md

- `sandbox-exec` profiles describe **what's allowed**; everything else is denied. That's opposite to bwrap's "describe what's bound."
- Apple has been quietly trying to phase out the standalone binary for years, but it's still in `/usr/bin/sandbox-exec` on every macOS release through Sequoia. Treat this as practitioner-functional but not part of any supported public API.
- The profile DSL is Scheme-like and underdocumented. The most useful reference is `/usr/share/sandbox/*.sb` (Apple's own profiles, which you can read) and `man sandbox-exec`.

### Verification checklist (Mac)

- [ ] `sandbox-exec -p '(version 1)(allow default)' true` exits 0
- [ ] `bash mac/sandbox-permissive.sh` runs the cred-scrub probe and shows dotfiles `present`
- [ ] `bash mac/sandbox-hardened.sh` shows dotfiles `clean` (the hardened profile denies file reads outside the workshop dir)

---

## Windows scaffold

### AppContainer and Job Objects

Windows has two distinct process-isolation primitives that together form the closest analog to bwrap:

- **AppContainer.** A token-based sandbox that restricts what objects a process can access. Originally for UWP apps; can be applied to arbitrary processes with the right APIs.
- **Job Objects.** A way to group processes and apply resource limits, kill-on-close, restrictions on what they can spawn.

There's no single CLI like `bwrap` that combines them — you typically write a small launcher (in C++, C#, or PowerShell using `Add-Type`) that creates an AppContainer profile, sets up a Job, then `CreateProcess`es the target into it.

### Realistic options for the Windows port

Three honest paths:

1. **Use `WSL 2` and follow `linux/`.** WSL is Linux for our purposes; bwrap works inside it. This is the practitioner-honest answer for most Windows users running agents — they're already in WSL anyway.
2. **Use Windows Sandbox.** Microsoft's disposable VM. Closer to Tier 3 than Tier 1 but it's the most accessible "isolate this command on Windows" tool. Could be its own topic.
3. **Native AppContainer launcher.** Substantial Windows-API code; not a 1:1 with the rest of this track. If we go this route, the workshop becomes a Windows-API tutorial as much as a sandbox tutorial.

The recommended path for the participant is **(1) WSL + Linux folder**. That's what `windows/notes.md` should say up front.

### Files to create at `topics/sandboxing/process-isolation/windows/`

| File | Content |
|------|---------|
| `notes.md` | Explains the WSL-recommended path; describes AppContainer and Windows Sandbox as alternatives with their trade-offs; provides links to Microsoft docs for participants who want to write a native launcher. |

That's it for the first pass. A native AppContainer launcher is a separate project; the WSL pointer covers most users.

---

## Once each platform is built and verified

1. Update `README.md` in this topic.
2. The workshop body in `workshop.md` is currently bwrap-specific; rewrite it once the platforms exist to be tool-agnostic at the top and platform-specific in the runnable steps.

If the bwrap-specific framing in `workshop.md` proves too tightly coupled to one tool, factor the "what process-level isolation does" into a platform-agnostic section, with a per-platform "how to do it" section below.
