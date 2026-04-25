# Mac notes

Platform-specific notes for the Mac probe and scrubber. The cross-platform reference is at `../categories.md`.

## Direnv setup on Mac

If you've never used direnv on Mac, install it via Homebrew:

```sh
brew install direnv
```

Then hook it into your shell. Add the line for your shell to your rc file:

```sh
# ~/.zshrc (default on Catalina and later)
eval "$(direnv hook zsh)"

# ~/.bash_profile (if you've switched back to bash)
eval "$(direnv hook bash)"
```

Start a new shell. From then on, `direnv allow` in any directory enables the `.envrc` for that directory, and direnv loads/unloads it whenever you `cd` in or out.

If you skip the hook, `.envrc` doesn't auto-fire on `cd`. You'd have to `source .envrc` manually each time, which defeats the auto-on-cd point.

## Keychain

The macOS Keychain is the load-bearing keystore on Mac. The probe checks for the login keychain file at `~/Library/Keychains/login.keychain-db` (Catalina+) or `~/Library/Keychains/login.keychain` (older).

Important things to know:

- **Keychain access prompts.** When an application first asks for an item from the Keychain, you typically get a "do you want to allow X to access this item?" popup. This is a real (if interactive) defense against agents reading items they shouldn't — *if* you don't habit-click "Always Allow." If you have allowed an app/agent in the past, it gets the item silently.
- **Login keychain auto-unlocks at login.** The keys inside aren't "locked" while you're logged in — they're encrypted at rest, decrypted in memory.
- **The Tier 0 scrubber doesn't disconnect from Keychain.** No env var redirects Keychain access. To scope an agent's Keychain reach you'd need Tier 1 (`sandbox-exec` profile) or Tier 2+ (a container that doesn't have access to your home).

## SSH agent on Mac

`unset SSH_AUTH_SOCK` is aggressive — it disconnects the current shell from any loaded SSH keys. macOS launchd manages an ssh-agent service per-session and exports `SSH_AUTH_SOCK` automatically; unsetting it in this shell only affects this shell, not the launchd-managed agent itself.

For an untrusted workload (CTF, evaluating an unfamiliar tool, running an agent on questionable input) this is right. For your everyday dev shell where `git push` needs to work, you wouldn't want this.

The right framing: `.envrc` in this directory is for things that should *not* have your SSH keys. Drop it in directories where you run untrusted code. Don't drop it in your normal dev directory.

## Common gotchas

- **Default shell is zsh on Catalina+.** The probe and scrubber both work in zsh and bash. The probe is invoked as `bash mac/probe.sh` so it runs in bash regardless of your default.
- **`/dev/null` works on Mac the same as Linux.** It's a real character device at `/dev/null`. Tools that read from `KUBECONFIG=/dev/null` see an empty file.
- **`mktemp -d` on Mac** is BSD-style, slightly different from GNU. The scrubber uses the portable form `mktemp -d "${TMPDIR:-/tmp}/cred-scrub-empty-XXXXXX"` which works on both.
- **Homebrew tools.** If you have `brew`-installed AWS CLI, `gh`, etc., they read from the same env vars and dotfiles as their Linux counterparts. The scrubber's coverage is the same.
- **System Integrity Protection (SIP) and Gatekeeper.** SIP doesn't affect the scrubber; the scrubber only modifies your shell environment, not system files.
- **Agents launched outside this shell.** If you start an AI tool from Spotlight, Alfred, or a Dock icon, it inherits the *desktop session* environment, not your direnv-loaded one. Always launch agents from a terminal with this directory's `.envrc` loaded.
