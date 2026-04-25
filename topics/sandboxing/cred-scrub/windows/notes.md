# Windows notes

Platform-specific notes for the Windows probe and scrubber. The cross-platform reference is at `../categories.md`.

> **Status: untested on Windows.** These scripts were written from documented behavior, not run on a real Windows machine. The "Things to verify" list at the bottom of this file calls out the specific behaviors a Windows tester needs to confirm before this lands in a workshop.

## What you need

- **PowerShell 7+** (`pwsh`). The scripts use modern syntax and `[string]::IsNullOrEmpty`, `Get-ChildItem env:`, etc. Windows PowerShell 5 may also work but isn't tested.
- **Git Bash, WSL, or PowerShell.** This folder targets PowerShell. If you're using WSL, follow the `linux/` folder instead — WSL is Linux for our purposes.
- Optional: `direnv` for PowerShell.

## Direnv on Windows

Direnv is available on Windows via:

- **Scoop**: `scoop install direnv`
- **Chocolatey**: `choco install direnv`
- **Manual binary**: download from the direnv releases page, put on PATH

Once installed, hook into PowerShell:

```powershell
# Add to your PowerShell profile (run `notepad $PROFILE` to edit)
Invoke-Expression "$(direnv hook pwsh)"
```

Restart PowerShell. From then on, `direnv allow` in any directory enables a `.envrc` for that directory and direnv loads/unloads it on `cd`.

If you don't want to install direnv, you can dot-source the scrubber manually:

```powershell
. .\solution.profile.ps1
```

This applies the scrubber to the current PowerShell session only. New shells don't inherit it.

## NUL vs /dev/null

Windows uses `NUL` (a special filename, not a path) as its null device. `KUBECONFIG=NUL` should make `kubectl` read an empty file when it tries to load its config. The scrubber sets all file-based redirect vars to `NUL`.

If a tool you're testing doesn't accept `NUL` and errors out, two fallbacks:

- Set the var to a real path that doesn't exist (e.g., `$env:KUBECONFIG = "$env:TEMP\nonexistent-config"`).
- Set the var to a real path that points at an empty file you create.

## Windows Credential Manager

The probe uses `cmdkey /list` to count entries in Windows Credential Manager. This shows you what's stored, but doesn't tell you which entries an arbitrary process can access — that depends on the entry's persistence type (session, local machine, enterprise) and the process's user context.

The Tier 0 scrubber **does not** disconnect your session from Credential Manager. Anything running as your user can call the Credential Manager API. Scoping that requires Tier 1+ (running the agent as a different user, in a sandbox, or in a container/VM that doesn't have your user profile mounted).

## DPAPI

Many Windows apps use DPAPI (Data Protection API) to encrypt local secrets. Browsers, RDP saved passwords, some token stores. DPAPI uses the user's login credential to derive a master key — so anything running as your user can decrypt anything you've encrypted.

The probe doesn't try to detect DPAPI-protected secrets — there's no clean way to enumerate them. Just be aware: scrubbing your shell environment doesn't protect anything DPAPI is sitting on.

## SSH on Windows

Windows 10/11 ships an OpenSSH client and `ssh-agent` service. The agent runs as a Windows service (`Get-Service ssh-agent`), independent of any shell. The scrubber's `Remove-Item env:SSH_AUTH_SOCK` is mostly symbolic on Windows because Windows OpenSSH talks to the service via a named pipe rather than `$SSH_AUTH_SOCK`.

To actually scope SSH agent access on Windows you'd need to stop the service or run the agent under a different account. That's beyond this workshop.

## Common gotchas

- **Profile location:** PowerShell loads scripts from `$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` (PowerShell 7) or `...\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (Windows PowerShell). Check `$PROFILE` to see which.
- **Path separators:** PowerShell tolerates both `/` and `\`. The probe uses `\` for Windows paths.
- **Execution policy:** First-time users may see "running scripts is disabled on this system." Set the policy with `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` (then accept).
- **Path conventions:** `$env:USERPROFILE` is `C:\Users\<you>`. `$env:APPDATA` is `C:\Users\<you>\AppData\Roaming`. Some tools store config in `~` (which PowerShell expands to `$env:USERPROFILE`), others in `$env:APPDATA`.

## Things to verify before this hits a workshop

A Windows tester should confirm each of the following:

- [ ] `$env:KUBECONFIG = 'NUL'` makes `kubectl get pods` fail to find a config (rather than reading `%USERPROFILE%\.kube\config`).
- [ ] `$env:AWS_SHARED_CREDENTIALS_FILE = 'NUL'` makes `aws sts get-caller-identity` fail to find creds (rather than reading `%USERPROFILE%\.aws\credentials`).
- [ ] `$env:GIT_CONFIG_GLOBAL = 'NUL'` makes `git config --global --list` return empty (rather than reading the user's global `.gitconfig`).
- [ ] The probe's Credential Manager check (`cmdkey /list | Where-Object { $_ -match 'Target:' }`) gives a sensible count on a fresh user with a few stored credentials.
- [ ] `Get-Service ssh-agent` returns `Running` when the agent service is up, `Stopped` otherwise.
- [ ] `pwsh -NoProfile -File .\probe.ps1` runs cleanly with the expected output shape.
- [ ] `pwsh tests\run.ps1` runs cleanly and produces a PASS for the seed scenario.
