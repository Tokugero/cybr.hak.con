# Linux notes

Platform-specific notes for the Linux probe and scrubber. The cross-platform reference is at `../categories.md`.

## Direnv setup

If you've never used direnv before, you need to hook it into your shell once. Add the line for your shell to your rc file:

```sh
# ~/.bashrc
eval "$(direnv hook bash)"

# ~/.zshrc
eval "$(direnv hook zsh)"

# ~/.config/fish/config.fish
direnv hook fish | source
```

Then start a new shell. From that point on, `direnv allow` in any directory enables the `.envrc` for that directory, and direnv loads/unloads it whenever you `cd` in or out.

If you skip the hook, direnv won't fire automatically — you'd have to `source .envrc` by hand each time, which defeats the auto-on-cd point.

## Keystores

Linux has several common keystores; presence and behavior varies by distro.

- **GNOME Keyring.** Often the default on GNOME-based distros. Auto-unlocks at login. Stores SSH passphrases, application credentials, sometimes GPG keys. The probe looks for the `gnome-keyring-daemon` process — if it's running, the keyring is unlocked and reachable from this shell session. Your scrubber doesn't disconnect from the keyring; that would need Tier 1+ (process-level isolation).
- **KWallet.** KDE's equivalent. Daemons are `kwalletd5` or `kwalletd6` depending on Plasma version. Same exposure shape as GNOME Keyring.
- **`pass`.** The standalone command-line password manager. Uses GPG for encryption, store at `~/.password-store/`. The probe checks for the directory because the binary alone doesn't mean active use.

The Tier 0 scrubber doesn't disconnect from these keystores — they're independent of your shell environment. If you want to scope keyring access for an agent, that's a Tier 1+ problem (sandbox the agent process so it can't talk to the keystore D-Bus socket).

## SSH agent

`unset SSH_AUTH_SOCK` is aggressive — it disconnects the current shell from any loaded SSH keys. For an agent context this is usually right (you don't want loaded prod keys reachable to whatever you're running). For a regular dev shell where you want `git push` to work, you wouldn't unset it.

The right framing for the workshop: this directory's `.envrc` is for things that should NOT have your SSH keys. Use it on directories where you run untrusted code or evaluate new tools. Don't drop it in your normal dev directory.

If GNOME Keyring or another agent provides SSH-agent-compatible service, `unset` removes the env var pointing at the socket but doesn't kill the daemon. A child process that knows where to look (e.g., `~/.gnupg/S.gpg-agent.ssh`) could still find it. Worth knowing if you're trying to harden, not just tidy.

## Common gotchas

- **Login vs. non-login shells.** Some distros export cloud credentials only in `~/.profile` (login shell) and not `~/.bashrc` (interactive non-login). Run the probe both from a fresh terminal *and* from a session where you've explicitly run an installer's "set up your shell" step, to see the difference.
- **Shell vs. desktop session env.** GUI applications inherit env from the desktop session, set very early in login. `unset` in `.envrc` only affects the current shell — if you launch an agent from a desktop launcher (not from a shell that's `direnv allow`-ed this directory), it'll have the un-scrubbed env. Always launch agents from a shell that has direnv loaded for this directory.
- **WSL.** WSL is Linux for our purposes; this probe and scrubber work as-is. Windows credentials in `%USERPROFILE%` aren't reachable from WSL by default, but watch for `wslg` mounts and any custom integration you've set up that bridges the two.
- **NixOS / non-FHS distros.** Paths like `~/.aws` and `~/.ssh` work the same. Direnv works the same. Some GNOME Keyring / KWallet defaults may differ; check `pgrep` output if the probe's keystore detection looks wrong.
