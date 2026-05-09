# Other platforms

This workshop is implemented for Linux only. The *categories* of credentials to scrub are platform-agnostic — `categories.md` is the cross-platform reference and applies as-is. What changes per platform is (1) the probe shell, (2) the scrubber syntax, and (3) the OS-level keystore that lives next to env vars and dotfiles. Ask your agent to translate `linux/` into your platform.

## Mac equivalents

- Probe and scrubber stay in `bash` / `zsh`. The `linux/probe.sh` is mostly portable; `realpath` differs slightly between BSD and GNU.
- Scrubber is still a `.envrc` evaluated by direnv.
- Keystore: macOS Keychain, accessed via the `security` CLI. Out of scope for the scrubber (which targets env vars and dotfile redirects), but worth a row in the probe so participants see what isn't being addressed.

## Windows equivalents

- Probe is PowerShell. `Get-ChildItem env:`, `Test-Path`, `[string]::IsNullOrEmpty` replace the bash patterns.
- Scrubber is a PowerShell `$PROFILE` snippet *or* a direnv `.envrc` (direnv on Windows still evaluates `.envrc` in its bundled bash; exported values become `$env:VARNAME`).
- Keystore: Windows Credential Manager + DPAPI. Same scope caveat as Keychain — show it in the probe, don't try to scrub it.
- Dotfile paths: `%USERPROFILE%\.aws\` etc. Forward slashes work in most CLIs but the canonical form is backslash.

## Gotchas your agent won't infer

- **Don't try to scrub the OS keystore.** Keychain / Credential Manager unlock on user login and stay accessible for the session; an agent that needs them can ask the OS. The honest framing is to *probe* for what's reachable there and treat it as a known limit, not a target. Tell your agent the same.
- **PowerShell has no clean subshell.** The Linux test harness uses `bash -c` to seed-then-probe in isolation; on Windows you need to spawn a child `pwsh` process to get the same env-isolation guarantees. If your agent generates a one-process test, the assertions will be polluted by parent state.
- **`.envrc` on Windows is bash, not PowerShell.** If your agent tries to put PowerShell in an `.envrc`, it will fail silently — direnv evaluates the file in its bundled bash and the PowerShell hook only ingests the resulting env exports.
- **`AWS_REGION` and other "selector" vars look harmless but matter.** A scrubber that only unsets `*_KEY` / `*_TOKEN` leaves the agent able to resolve credentials by profile or default region. The Linux scrubber treats `AWS_PROFILE`, `AWS_DEFAULT_PROFILE`, `AWS_REGION`, `KUBE_CONTEXT`, etc. as Layer 1 — keep that posture in the port.

## Asking your agent

A starting prompt:

> Translate `linux/probe.sh` and the `.envrc`-based scrubber into `<mac/probe.sh | windows/probe.ps1>` and the matching scrubber. Use `categories.md` as the source of truth for which vars and dotfiles to cover; don't add or drop categories. For Windows, write the test harness so each probe runs in a fresh child `pwsh` process. Add a probe row for the OS keystore (Keychain / Credential Manager) and treat it as out-of-scope, not a scrub target.

See `discussion.md` for the full prompt scaffold.
