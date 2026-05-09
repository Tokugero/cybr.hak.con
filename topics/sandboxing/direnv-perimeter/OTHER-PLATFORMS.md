# Other platforms

This workshop is implemented for Linux only. Direnv ports more easily than most topics in this track because `.envrc` files are bash on every platform — direnv ships its own bash interpreter for evaluating them. The platform-specific work is in the fingerprint script (which introspects the host shell) and the test harness. Ask your agent to translate `linux/` into your platform.

## Mac equivalents

- `brew install direnv`; hook into zsh with `eval "$(direnv hook zsh)"` in `~/.zshrc`.
- `fingerprint.sh`, `sample.envrc`, the nested-`.envrc` example all translate as direct copies — `uname -s` returns `Darwin` but the rest of the script is identical.

## Windows equivalents

- `scoop install direnv` (or `choco install direnv`); hook into PowerShell `$PROFILE` with `Invoke-Expression "$(direnv hook pwsh)"`.
- `fingerprint.sh` becomes `fingerprint.ps1` — that's the bulk of the rewrite.

## Gotchas your agent won't infer

- **`.envrc` is always bash, even on Windows.** Direnv evaluates `.envrc` in its bundled bash. You don't write PowerShell in `.envrc`; you write bash, and exported variables show up as `$env:VARNAME` in the parent PowerShell session.
- **Path conventions in `.envrc` use forward slashes** even on Windows — bash treats `\` as escape. Direnv passes the value to PowerShell verbatim.
- **`[string]::IsNullOrEmpty($env:DIRENV_DIR)` for the perimeter check** — PowerShell's null/empty distinction matters; a naive `if (-not $env:DIRENV_DIR)` will misbehave for empty strings.
- **DPAPI / Credential Manager are out of scope here.** Direnv-perimeter is about the directory-as-boundary, not credential stores. cred-scrub is the topic for keystores.

## Asking your agent

A starting prompt:

> Translate `linux/fingerprint.sh` into `<mac/fingerprint.sh | windows/fingerprint.ps1>`. The `.envrc` and nested-`.envrc` files are direct copies — they're pure bash and direnv evaluates them the same way on every platform. Preserve the perimeter-detection rows (DIRENV_DIR sentinel, `.envrc here`, scoped vs default values).

See `discussion.md` for the full prompt scaffold.
