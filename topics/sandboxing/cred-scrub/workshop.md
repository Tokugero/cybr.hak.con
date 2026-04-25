# Workshop: credential scrubbing

A hands-on exercise. Run the probe, look at the scrubber, watch the diff. The diff is the lesson.

Substitute your platform (`linux/`, `mac/`, `windows/`) wherever you see `<platform>` below.

## 1. See what your shell exposes right now

From this directory, run the probe for your platform:

```sh
bash <platform>/probe.sh        # Mac, Linux, WSL
```

```powershell
pwsh <platform>/probe.ps1       # Windows
```

The probe walks credential categories (cloud, infrastructure, source control, LLM keys, agents, OS keystores, default-path redirects) and prints a fixed-width report showing what's reachable in your current shell.

Examples of what you might see:

```
AWS env vars              | exposed    | 3 vars: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_PROFILE
AWS config                | present    | ~/.aws
SSH agent                 | active     | /tmp/ssh-XXX (2 keys loaded)
Kubeconfig                | default    | KUBECONFIG unset; tool reads disk default
```

Each row tells you something different:

- **`exposed`** — a credential is in your environment. Anything in this shell can read it.
- **`present`** — there's a credential file on disk. The scrubber doesn't remove these but you should know they're there.
- **`active`** — an agent (SSH, GPG, OS keystore) is running and reachable.
- **`default`** — a tool's config-redirect env var is unset, so the tool will fall back to its default path on disk (`~/.kube/config`, `~/.aws/credentials`, etc.).
- **`redirected`** — the tool's config-redirect env var points at `/dev/null` or an empty directory; the tool will not find anything via the default path.
- **`set`** — a config-redirect env var is set to an explicit path. Worth noticing — could be intentional, could be leakage from your parent shell.
- **`clean`** — the category has nothing in it.
- **`n/a`** — doesn't apply on this platform.

This is what an agent running in your shell sees. Save the output — we'll diff against it later.

## 2. Look at the scrubber

Open the scrubber for your platform:

- `<platform>/solution.envrc` (Mac, Linux, WSL)
- `<platform>/solution.profile.ps1` (Windows)

It has **two layers**:

**Layer 1 — unset credential values.** A list of `unset` (or `Remove-Item Env:`) calls grouped by category: cloud, infrastructure, source control, LLM keys, package registries, secrets managers, hosting/CDN, SSH agent. This removes any credentials currently exported into your shell.

**Layer 2 — redirect default config paths.** A shorter list of `export VAR=/dev/null` (file-based) and `export VAR=<empty dir>` (directory-based) calls for vars like `KUBECONFIG`, `AWS_CONFIG_FILE`, `TALOSCONFIG`, `CLOUDSDK_CONFIG`, etc. This doesn't remove credentials — it points the tools at empty configs so they can't fall back to `~/.kube/config`, `~/.aws/credentials`, etc. when the credential env vars are unset.

Why both layers matter: unsetting `KUBE_TOKEN` doesn't stop `kubectl` from reading `~/.kube/config`. Unsetting `AWS_PROFILE` doesn't stop `aws` from reading `~/.aws/credentials`. Layer 2 is what closes that gap.

Read your platform's `<platform>/notes.md` for platform-specific gotchas (Keychain on Mac, GNOME Keyring/KWallet/`pass` on Linux, Credential Manager and DPAPI on Windows).

## 3. Apply the scrubber to a directory

Pick a fresh empty directory anywhere outside this repo:

```sh
mkdir -p ~/sandbox-test
cp <platform>/solution.envrc ~/sandbox-test/.envrc
cd ~/sandbox-test
direnv allow
```

`direnv allow` is the trust gate. Direnv asks you to acknowledge `.envrc` before running it, every time the file changes. That's direnv's own contribution to Tier 0 — recognize it as a feature, not a nag.

When direnv loads, it should print a status banner from the scrubber.

If you don't have direnv hooked into your shell yet, see your platform's `notes.md` for the one-time install step. Without the hook, `.envrc` doesn't fire on `cd` and the workshop loses its point.

## 4. Re-probe in the scrubbed directory

```sh
bash <repo>/topics/sandboxing/cred-scrub/<platform>/probe.sh
```

Compare against step 1. You should see:

- **Layer 1 effect:** `exposed` rows for credential env vars now read `clean`.
- **Layer 2 effect:** `default` rows for config-redirect env vars now read `redirected`.
- **Unchanged:** `present` rows for dotfiles, plus any `active` agent rows the scrubber didn't address (e.g., GPG agent).

The `present` rows that didn't move are the lesson. The agent can still read those files directly; the scrubber doesn't touch your filesystem. That's why this is **Tier 0 hygiene**, not a sandbox.

## 5. The Tier 0 limit, in one screen

Inside the scrubbed shell, try both of these:

```sh
direnv exec . kubectl get pods
direnv exec . head ~/.kube/config
```

The first call uses `kubectl`, which reads `KUBECONFIG=/dev/null` and finds nothing. It can't reach your cluster.

The second call reads the file directly. It works fine. The agent has full read access to `~`.

Both happen in the same shell at the same time. That's the entire honest framing of this workshop:

> Layer 1 + Layer 2 scope what *automated tooling* can find.
> They do not stop a malicious read of files under `~`.
> To do that you need at least Tier 1 (process-level filesystem restriction) or Tier 2+ (the agent doesn't have your `$HOME` mounted at all).

## 6. The perimeter — LLMs and their subagents

So far, you've run the probe from your terminal directly. The bigger lesson is that anything *spawned* from inside the scrubbed directory inherits the cleaned environment too: your LLM client, the shell commands it runs on your behalf, and any subagents it spawns.

This is what makes direnv a *boundary mechanism*. The perimeter is the directory. Any process whose parent chain crosses that perimeter sees the scrubbed environment.

### The catch — restart the LLM after the perimeter is set

If your LLM client is already running, it inherited *your parent shell's* environment when you launched it. That environment was probably never scrubbed. Anything it spawns now will get the un-scrubbed env, even if you `cd` into the scrubbed directory from inside the LLM session. The perimeter does not apply retroactively to a process that was already running.

To test the perimeter honestly, the order matters:

1. Quit your current LLM session.
2. Open a fresh terminal.
3. `cd` into your scrubbed directory. Direnv fires. You see the status banner.
4. Verify the scrub took effect:
   ```sh
   bash <repo>/topics/sandboxing/cred-scrub/<platform>/probe.sh
   ```
5. **Now** launch your LLM: `claude`, `opencode`, or whatever you use.
6. Ask the LLM to run the probe:
   > Run `bash <repo>/topics/sandboxing/cred-scrub/<platform>/probe.sh` and show me the output.

The LLM's probe output should match the shell's. The LLM is a child process of the scrubbed shell; its environment is the scrubbed environment.

### Verify whether the perimeter actually applied

A subtle thing worth checking: being *inside* a directory with a scrubbed `.envrc` doesn't guarantee your LLM is using it. Direnv's standard shell hook (`eval "$(direnv hook bash)"`) is interactive-only — it fires on the prompt of an interactive shell, not on the non-interactive shells that LLM tools spawn for their `Bash` calls. So when you `cd` into a perimeter directory from *inside* an already-running LLM session, the `.envrc` doesn't fire automatically. You'd be in the right directory with the wrong environment, and never know.

The cheapest way to confirm: ask the LLM to run the probe two ways, from inside the perimeter directory:

```sh
bash <repo>/topics/sandboxing/cred-scrub/<platform>/probe.sh
direnv exec . bash <repo>/topics/sandboxing/cred-scrub/<platform>/probe.sh
```

The first runs the probe in whatever environment the LLM launched with. The second uses `direnv exec`, which forces the `.envrc` to apply regardless of how the LLM was launched.

- **Outputs match** → the perimeter is applied. Your LLM was launched from a shell that already had direnv loaded for this directory, and inheritance carried it through.
- **Outputs differ** (only the second one shows `redirected` rows; the first one shows `default`) → the perimeter is NOT applied. Your LLM is still using its launch-time environment. To fix: restart the LLM from a shell that has direnv active for this directory, or wrap commands in `direnv exec . --` from now on.

Rows worth eyeballing for the diff: `AWS config file`, `Kubeconfig`, `Talos config`, `SSH agent`. Those are the cleanest signals — they go from `default` / `active` (perimeter not applied) to `redirected` / `clean` (perimeter applied).

That diff is the fastest way to know the truth about your session.

### Subagents (if your LLM has them)

If your LLM has a subagent or task tool (Claude Code's Agent / Task, opencode's equivalents), ask it to spawn one:

> Spawn a subagent and ask it to run `bash <repo>/topics/sandboxing/cred-scrub/<platform>/probe.sh`. Show me its output.

The subagent's output should match too. Subagents are child processes of the LLM. They inherit the LLM's environment, which is the scrubbed environment.

### What this proves

- The perimeter is the directory, not the LLM session.
- Anything spawned inside the perimeter — shells, processes, subagents — inherits the scrubbed environment by default.
- A subagent born inside the perimeter has no path to your real credentials *through its environment*. It can still read files under `~`, which is the same Tier 0 limit you saw in step 5.

### Failure modes worth knowing

The perimeter is real but not unbreakable. Things that can punch through it:

- **Launching the LLM from outside the directory.** The LLM has your un-scrubbed env; everything it spawns inherits that.
- **Tools that re-source shell rc files.** Some agents shell out via `bash -l` or `bash -c "source ~/.bashrc; …"`, which re-loads your dotfiles and can re-introduce credentials.
- **Cached credentials in keystores.** A previously-authenticated `aws sso login` may have a token sitting in the OS keychain. The scrubber doesn't touch keystores.
- **Long-lived processes started before the perimeter.** A `tmux` session, an `screen` session, a previously-launched browser — all started before this directory existed, all still hold the old environment.
- **Subagents that explicitly re-import env from the host.** If a subagent's runner reads `/proc/<parent>/environ` or similar, it can pull values you didn't intend to expose.

These are the things to probe in subsequent topics. For now: the default behavior is inheritance, and inheritance is what makes Tier 0 hygiene worth doing across an LLM workflow.

## 7. Optional: run the test harness

To verify the scrubber against a known-seeded environment instead of your real one:

```sh
bash <platform>/tests/run.sh
```

```powershell
pwsh <platform>/tests/run.ps1
```

This:

1. Creates a temporary `HOME` directory.
2. Seeds it with fake credentials in env vars and dotfiles.
3. Runs the probe to baseline.
4. Sources the scrubber.
5. Runs the probe again.
6. Prints a summary table: how many categories went from `exposed` → `clean` and from `default` → `redirected`.

The summary is the data. None of your real credentials are touched.

## 8. Where to next

`discussion.md` has prompts written to be handed directly to your LLM. The most useful ones for what you just saw are:

- "What can a malicious agent still read after I've scrubbed my shell? Walk me through the steps it would take to find AWS credentials anyway."
- "If I run my agent inside a Docker container, do I still need this scrubber?"
- "Read `topics/sandboxing/README.md` and tell me where this technique sits, and what's the next tier up I'd reach for if S1 isn't enough."

Direnv as a sandbox *boundary* mechanism — anything spawned in this directory inherits these rules — will be its own future topic in this track.
