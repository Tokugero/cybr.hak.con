# Other platforms

This workshop is implemented for Linux only (`bubblewrap`). The Tier 1 concept ports, but the implementation is a full rewrite per platform. Rather than maintain parallel ports, this file names the equivalents and the gotchas your agent wouldn't infer from the Linux code; ask it to translate `linux/` into your platform.

## Mac equivalents

- `sandbox-exec` — wraps a command in a profile written in a Scheme-like DSL. Officially deprecated for app developers but still shipped on every macOS release through Sequoia and used by, e.g., Homebrew's build sandbox.
- App Sandbox / entitlements — Apple's preferred replacement, but it targets bundled `.app`s and doesn't apply cleanly to "wrap an arbitrary command."

## Windows equivalents

- AppContainer + Job Objects — the closest analog to bwrap, but there is no `bwrap`-style CLI. You write a small launcher (PowerShell with `Add-Type`, or C#/C++) that creates the AppContainer profile, sets up the Job, then `CreateProcess`es into it.
- The practitioner answer for most Windows users running agents is **WSL 2 + the Linux folder**. WSL is Linux for our purposes; bwrap works inside it.
- Windows Sandbox is the other accessible option, but it is closer to Tier 3 than Tier 1 — see `vm-isolation/`.

## Gotchas your agent won't infer

- `sandbox-exec` profiles describe **what's allowed**; everything else is denied. That's *opposite* to bwrap, which describes what's bound (everything else is unreachable). A naive translation will produce a profile that allows nothing useful.
- The sandbox-exec profile DSL is underdocumented; the most useful reference is `/usr/share/sandbox/*.sb` (Apple's own profiles) and `man sandbox-exec`. Tell your agent to read those before generating a profile.
- On Windows there is no clean 1:1 with bwrap. If you ask for one, you'll get something that compiles but doesn't isolate — the AppContainer model is token-based, not bind-mount-based, and the threat model is different.

## Asking your agent

A starting prompt:

> Translate `linux/bwrap-hardened.sh` into a `<mac|windows>/` equivalent using `<sandbox-exec | AppContainer | WSL>`. Preserve the same threat goals (block reads outside the workshop dir, no network unless asked). Read `linux/notes.md` for the security intent before producing code. Note the allow-list-vs-bind-list inversion if you target sandbox-exec.

See `discussion.md` for the full prompt scaffold.
