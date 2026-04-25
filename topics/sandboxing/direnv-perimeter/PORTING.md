# Porting direnv-perimeter to Mac and Windows

This is a handoff doc. The `linux/` folder has the verified, working version of the workshop. Mac and Windows aren't built yet. This file tells a future agent (or anyone with access to those platforms) exactly what to create and what to expect.

The good news: direnv-perimeter ports more easily than cred-scrub did, because the `.envrc` files themselves are bash syntax on every platform — direnv ships its own bash interpreter for evaluating them. The platform-specific work is in (1) the fingerprint script that introspects the host shell, and (2) the test harness that runs everything.

## Mac scaffold

Most of `linux/` is a direct copy. Direnv on Mac behaves identically to Linux for everything this workshop cares about.

### Files to create at `topics/sandboxing/direnv-perimeter/mac/`

| File | Source | What changes |
|------|--------|--------------|
| `fingerprint.sh` | direct copy of `../linux/fingerprint.sh` | None. `uname -s` prints `Darwin`; the rest is the same. |
| `sample.envrc` | direct copy | None. Pure bash; direnv evaluates it. |
| `sample.envrc.local.example` | direct copy | None. |
| `nested/sample.envrc` | direct copy | None. `source_up` is direnv stdlib; same on every platform. |
| `notes.md` | rewrite | Mac-specific direnv setup. Skip kwallet/gnome-keyring discussion (those are Linux-only and irrelevant to direnv-perimeter anyway). |
| `tests/run.sh` | direct copy | Works as-is. The `mktemp -d "${TMPDIR:-/tmp}/...-XXXXXX"` form is already portable to BSD. |

### Mac-specific notes for `notes.md`

- Install: `brew install direnv`
- Hook (zsh is default on Catalina+): `eval "$(direnv hook zsh)"` in `~/.zshrc`
- `/dev/null` works the same as Linux
- The fingerprint and sample.envrc files are platform-agnostic — Mac and Linux can share them in principle, but we keep separate copies so each platform's folder is self-contained for participant clarity.

### Verification checklist (Mac)

On a clean Mac with direnv installed and hooked:

- [ ] `bash mac/fingerprint.sh` from outside any perimeter shows `DIRENV_DIR | unset`
- [ ] `cp mac/sample.envrc /tmp/test/.envrc && cd /tmp/test && direnv allow` loads cleanly
- [ ] `bash mac/fingerprint.sh` inside the perimeter shows sentinels and scoped values
- [ ] Nested `.envrc` with `source_up` inherits parent values (PERIMETER_ACTIVE, AWS_PROFILE) and overrides PERIMETER_NAME, AWS_REGION
- [ ] `bash mac/tests/run.sh` exits 0 with `PASS: perimeter behaviors as expected`
- [ ] The verification recipe (plain bash vs `direnv exec`) shows matching output when launched from a hooked shell, differing output otherwise

---

## Windows scaffold

More involved than Mac because PowerShell is the host shell, but the `.envrc` files themselves stay bash. Direnv on Windows still uses its own bash for `.envrc` evaluation; only the shell hook and the fingerprint script change.

### Files to create at `topics/sandboxing/direnv-perimeter/windows/`

| File | Source | What changes |
|------|--------|--------------|
| `fingerprint.ps1` | rewrite from `../linux/fingerprint.sh` | PowerShell port. Use the patterns from `../../cred-scrub/windows/probe.ps1` (`Get-ChildItem env:`, `$env:VARNAME`, `Test-Path`). |
| `sample.envrc` | direct copy of `../linux/sample.envrc` | None. Bash syntax; direnv handles it. |
| `sample.envrc.local.example` | direct copy | None. |
| `nested/sample.envrc` | direct copy | None. `source_up` is direnv stdlib. |
| `notes.md` | rewrite | Windows-specific direnv setup, PowerShell hook, file path differences (`$env:USERPROFILE`), how `.envrc` (bash) and the host shell (PowerShell) interact. |
| `tests/run.ps1` | rewrite from `../linux/tests/run.sh` | Port the seed → fingerprint → assert flow to PowerShell. Use the child-pwsh-process pattern from `../../cred-scrub/windows/tests/run.ps1` for env isolation. |

### Windows-specific notes for `notes.md`

- **Install direnv.** Scoop: `scoop install direnv`. Chocolatey: `choco install direnv`. Or download the binary and put it on `PATH`.
- **PowerShell hook.** Add to `$PROFILE`:
  ```powershell
  Invoke-Expression "$(direnv hook pwsh)"
  ```
  Restart pwsh. From then on, `direnv allow` in any directory enables its `.envrc`.
- **`.envrc` is always bash.** Even on Windows, direnv evaluates `.envrc` in its bundled bash. You don't write PowerShell in `.envrc` — you write bash. Variables exported from `.envrc` show up as `$env:VARNAME` in the parent PowerShell session.
- **Path conventions in `.envrc`.** Bash variables expand normally inside `.envrc`. If you set `$env:KUBECONFIG` to a Windows path, use forward slashes inside `.envrc` (bash treats `\` as escape) — direnv passes the value to PowerShell verbatim.
- **No DPAPI / Credential Manager interaction here.** This workshop is about the perimeter, not credentials reachable through OS keystores. cred-scrub is the topic for keystore concerns.

### Verification checklist (Windows)

On a clean Windows machine with PowerShell 7+ and direnv installed and hooked:

- [ ] `pwsh windows/fingerprint.ps1` outside any perimeter shows `DIRENV_DIR | unset`
- [ ] In a test directory: `cp windows/sample.envrc .envrc; direnv allow` loads cleanly (you should see direnv's status output)
- [ ] `pwsh windows/fingerprint.ps1` inside the perimeter shows sentinels and scoped values
- [ ] Nested `.envrc` with `source_up` inherits parent values and overrides only what the child specifies
- [ ] `pwsh windows/tests/run.ps1` exits 0 with `PASS: perimeter behaviors as expected`
- [ ] The verification recipe (plain `pwsh fingerprint.ps1` vs `direnv exec . pwsh fingerprint.ps1`) shows matching output when launched from a hooked shell, differing otherwise

### Likely gotchas (Windows)

- `Test-Path` returns `True`/`False`; the PowerShell fingerprint should use it for `.envrc here` rows.
- `$env:VARNAME` reads env vars; `${env:VARNAME}` is the dotted-form when interpolating in strings.
- The fingerprint's "is `DIRENV_DIR` set" check needs to handle PowerShell's null/empty distinction: `[string]::IsNullOrEmpty($env:DIRENV_DIR)`.
- The test harness's child-pwsh isolation pattern matters more on Windows than Linux because PowerShell doesn't have a clean subshell equivalent. Reuse what cred-scrub already worked out.

---

## Once each platform is built and verified

1. Update `README.md` in this topic — change `(coming soon)` to a real layout entry.
2. Update `topics/sandboxing/README.md` if needed (no change strictly necessary; the topic table already lists this topic).
3. Add an entry to a CHANGELOG / activity log if one exists at the time.
4. Commit with `feat(sandboxing): add <platform> port for direnv-perimeter` or similar.

If you find that one of the Linux-side files (sample.envrc, fingerprint.sh) needed adjustments to be portable, **lift those adjustments back into the Linux file too** so all platforms stay aligned. Cross-platform parity is the point.
