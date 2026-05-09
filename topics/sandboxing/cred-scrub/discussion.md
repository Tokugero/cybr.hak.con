# Discussion: cred-scrub

Questions you can hand to your LLM after running the workshop. Each is open-ended on purpose; the goal is to surface what credential scrubbing does and doesn't address, not to memorize a list of best practices.

## What this technique misses

- "What can a malicious agent still read after I've scrubbed my shell? Walk me through how it would find AWS credentials anyway."
- "What's the difference between a credential being in my environment and being on disk? When does that distinction matter to an attacker?"
- "If I scrub my shell but the agent runs `aws sso login` as part of normal use, what changes?"
- "What's the threat model where this technique provides zero defense?"

## Extending the technique

- "Look at `categories.md`. What credential categories aren't covered? What would I need to add to the probe and scrubber to cover them?"
- "How would I extend the probe to check for browser cookies (Chrome, Firefox)? What's hard about that?"
- "I keep my AWS profile in 1Password and use the CLI plugin. Does this scrubber help, hurt, or neither?"
- "What would a useful 'paranoid mode' add to the scrubber, and what would it break?"

## Composing with higher tiers

- "If I run my agent inside a Docker container, do I still need this scrubber? Where would the credentials need to be — and not be — for that to be safe?"
- "Read `topics/sandboxing/README.md` for the tier framing. Where does this technique sit, and what's the next tier up I'd reach for if S1 isn't enough?"
- "What's the right answer if the threat I'm worried about is S2 (a malicious MCP server) instead of S1 (a poisoned context)? Does scrubbing help at all?"

## Translating to your platform

The workshop ships a Linux probe and scrubber. Mac and Windows participants: use these prompts to drive your agent through the port. `OTHER-PLATFORMS.md` is the orientation it needs.

- "Read `OTHER-PLATFORMS.md` and `categories.md`, then translate `linux/probe.sh` into `<mac/probe.sh | windows/probe.ps1>`. Use `categories.md` as the source of truth — don't add or drop categories. Show me the diff and call out any row whose semantics differ on this platform."
- "What gotcha from `OTHER-PLATFORMS.md` would your first-draft translation get wrong by default — the keystore scope, the PowerShell subshell trap, or the `.envrc`-is-bash trap? Confirm which ones your version handles."
- "Now translate the scrubber the same way. After both files exist, run them against a seeded clean environment and compare the rows that move from `exposed` → `clean` and `default` → `redirected` against the Linux baseline. Where they differ, is that a bug or a real platform difference?"

## OS-specific gotchas

- "What happens to my `git push` if I `unset SSH_AUTH_SOCK` in this directory?"
- "If GNOME Keyring is unlocked when I open my shell, has `unset SSH_AUTH_SOCK` actually disconnected me from any keys, or is the keyring still going to re-supply them via `ssh-askpass`?"
- "On Mac, the Keychain prompts me when an app first asks for an item. What happens when an agent tries to read my Keychain — do I get prompted, or does it just work?"

## Where this technique can fail open

- "Is there a scenario where running this scrubber actively makes things worse?"
- "What if I source `.envrc` in a parent shell and then spawn a child? What inherits and what doesn't?"
- "What if direnv isn't installed on the system I'm working on? What's the failure mode?"
