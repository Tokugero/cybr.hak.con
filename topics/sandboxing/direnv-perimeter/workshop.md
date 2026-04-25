# Workshop: direnv as a perimeter

A hands-on exercise. You'll set up a directory perimeter, watch a fingerprint script confirm it's active, see how a nested `.envrc` overrides its parent, and learn the patterns for injecting *scoped* credentials instead of leaving your broad ones in scope.

Substitute your platform (`linux/`, `mac/`, `windows/`) wherever you see `<platform>` below.

## 1. What direnv actually does

Direnv is two pieces:

- **A shell hook.** When you add `eval "$(direnv hook bash)"` (or zsh, fish, pwsh) to your shell rc, your interactive shell calls direnv before each prompt. Direnv checks: did the working directory change? Is there an `.envrc` somewhere? Has it been allowed?
- **A trust gate.** Direnv refuses to execute an `.envrc` until you run `direnv allow` for that file. The first time, and again every time the file changes.

When you `cd` into a directory with an allowed `.envrc`, direnv loads it (executes it as bash, captures the env diff). When you `cd` out, direnv unloads it (restores the previous env). The window between cd-in and cd-out is the **perimeter** — and any process you start inside that window inherits whatever the `.envrc` set up.

Two things to internalize:

- **The hook is interactive-only.** It fires on the prompt of an interactive shell. Non-interactive shells (the kind LLM tools spawn for `Bash` calls) skip it. We covered the verification trick for this in cred-scrub Step 6; it applies here too.
- **`.envrc` runs as you, in bash, with full shell powers.** A malicious `.envrc` can `rm -rf ~` or steal your tokens before the trust gate ever asks. Don't `direnv allow` an `.envrc` you didn't read.

## 2. Run the fingerprint outside any perimeter

The fingerprint script reports whether direnv has loaded an `.envrc` for this shell, and what scoped values are set.

```sh
bash <repo>/topics/sandboxing/direnv-perimeter/<platform>/fingerprint.sh
```

You should see something like:

```
Indicator                      | Status   | Value
DIRENV_DIR                     | unset    | (no perimeter active for this shell)
PERIMETER_ACTIVE               | unset    | -
AWS_PROFILE                    | unset    | -
KUBECONFIG                     | unset    | -
.envrc here                    | no       | -
```

`DIRENV_DIR` is direnv's own marker — it sets that env var when an `.envrc` has been loaded. Empty means no perimeter.

## 3. Apply a sample perimeter

The `<platform>/sample.envrc` file is a teaching example. It does two things:

- **Scrub** a small set of broad credentials (illustrative subset; cred-scrub does this comprehensively).
- **Inject** a scoped persona: `AWS_PROFILE=engagement-test`, `KUBECONFIG=$PWD/.kubeconfig`, plus a sentinel `PERIMETER_ACTIVE=yes` so the fingerprint can spot us.

The values are placeholders. The real-world version of `AWS_PROFILE=engagement-test` would point at a profile in `~/.aws/config` that only AssumeRoles into a read-only role for this engagement. The shape of the perimeter is the lesson, not the specific values.

```sh
mkdir -p ~/perimeter-test
cp <repo>/topics/sandboxing/direnv-perimeter/<platform>/sample.envrc ~/perimeter-test/.envrc
cd ~/perimeter-test
direnv allow
```

`direnv allow` is the trust gate. Read what it's allowing before approving. The output should show direnv loading the `.envrc` and printing its status banner.

## 4. Re-run the fingerprint inside the perimeter

```sh
bash <repo>/topics/sandboxing/direnv-perimeter/<platform>/fingerprint.sh
```

Compare against step 2. You should now see:

- `DIRENV_DIR` set to your test directory.
- `PERIMETER_ACTIVE` set to `yes`.
- `PERIMETER_NAME` set to `sample`.
- `AWS_PROFILE` set to `engagement-test`.
- `KUBECONFIG` set to `~/perimeter-test/.kubeconfig`.

That's the perimeter active and visible.

## 5. Scoped injection — the patterns

Open `patterns.md`. It walks four patterns for *adding* narrowly-scoped credentials inside the perimeter, instead of leaving your broad credentials in scope:

- The `.envrc.local` (gitignored) pattern.
- `aws-vault exec` and AssumeRole into a scoped role.
- Kubernetes scoped contexts via per-directory kubeconfigs.
- Short-lived credentials from a secrets manager (Vault, sops, 1Password CLI).

These are descriptions, not runnable steps. The `<platform>/sample.envrc.local.example` file shows the shape of the local-secrets pattern. None of the patterns require a paid account to read about; some require one to actually use.

This is the half of Tier 0 cred-scrub doesn't cover. Removal alone leaves you unable to do legitimate work inside the perimeter. Scoped injection lets you do the work with the smallest set of credentials sufficient for the task.

## 6. Demonstrate nesting (and the gotcha)

Direnv supports nested `.envrc` files, but with an honest catch: **the child does NOT automatically inherit the parent**. By default, the child `.envrc` runs in a fresh environment — anything the parent set up is gone unless the child explicitly opts in.

The opt-in is `source_up`, a direnv stdlib helper. The sample nested `.envrc` calls it on its first executable line:

```sh
log_status "nested perimeter active"
source_up                       # inherit everything the parent set
export PERIMETER_NAME=nested    # override
export AWS_REGION=eu-west-1     # override
```

Without `source_up`, this child would start fresh and the fingerprint would show only `PERIMETER_NAME` and `AWS_REGION` set (everything from the parent gone). With `source_up`, the parent loads first, then the child overrides.

Try it:

```sh
mkdir -p ~/perimeter-test/nested
cp <repo>/topics/sandboxing/direnv-perimeter/<platform>/nested/sample.envrc ~/perimeter-test/nested/.envrc
cd ~/perimeter-test/nested
direnv allow
bash <repo>/topics/sandboxing/direnv-perimeter/<platform>/fingerprint.sh
```

The fingerprint should show:

- `PERIMETER_ACTIVE` still reads `yes` (inherited via `source_up`).
- `AWS_PROFILE` still reads `engagement-test` (inherited).
- `PERIMETER_NAME` now reads `nested` (overridden by the child).
- `AWS_REGION` now reads `eu-west-1` (overridden).

Now `cd ..` and re-run the fingerprint. Direnv unloads the nested `.envrc` and you're back to the parent's values. `cd ~` and re-run — direnv unloads the parent too; you're back to your baseline shell.

The lesson is twofold. First, layering works — a project-wide `.envrc` for shared scope, plus a per-engagement `nested/.envrc` for narrower scope, plus an `.envrc.local` for the secrets you can't commit. You compose layers; you don't rewrite a single sprawling file. Second, the layering is *opt-in* per file. If you forget `source_up`, the child silently replaces rather than extends — exactly the kind of mistake a hurried agent could make on your behalf.

## 7. Verify the perimeter applied to a running LLM session

This is the same recipe as cred-scrub Step 6. From inside the perimeter, ask your LLM to run two equivalent-looking commands:

```sh
bash <repo>/topics/sandboxing/direnv-perimeter/<platform>/fingerprint.sh
direnv exec . bash <repo>/topics/sandboxing/direnv-perimeter/<platform>/fingerprint.sh
```

If the outputs match → the perimeter is applied. If they differ (only the second one shows `DIRENV_DIR` set and your scoped values present), the perimeter isn't applied to the LLM's shells. To fix: restart the LLM from a shell that has direnv hooked and the perimeter loaded, or wrap commands in `direnv exec . --` from now on.

## 8. Where the perimeter falls short

Worth knowing what it doesn't address:

- **Malicious `.envrc` itself.** The trust gate is one click. If an `.envrc` is compromised between two `direnv allow` cycles (e.g., by something the agent edited), direnv will warn — but if you allow it without reading the diff, you're done. *Read your `.envrc` diffs before allowing.*
- **Per-shell scope, not per-process.** If you start a long-lived process from inside the perimeter, then `cd` out, that process keeps the perimeter env. `cd`-ing out doesn't kill children. Watch out for `tmux` or `nohup` invocations that outlive the cd.
- **Re-sourcing rc files.** Tools that shell out via `bash -l` re-load your `~/.bashrc`, which can re-introduce credentials direnv just stripped. The agent may use cleaner subprocess invocations, but a third-party tool might not.
- **Already-running LLMs.** Same caveat as cred-scrub: the LLM has the env it was launched with. `cd`-ing into the perimeter from inside the LLM doesn't apply the perimeter — see step 7.
- **OS keystores aren't in scope.** Direnv changes shell env. It doesn't disconnect you from GNOME Keyring, Keychain, or Credential Manager. Those need Tier 1+ to scope.

## 9. Where to next

`discussion.md` has prompts written to be handed directly to your LLM:

- "Walk me through integrating `aws-vault exec` into the sample `.envrc`. What changes?"
- "If my agent edits `.envrc` while I'm working, what happens, and how do I notice?"
- "Compare a single committed `.envrc` against the `.envrc` + `.envrc.local` pattern. What threats does the split address?"

The next step up the tier ladder — actual filesystem isolation rather than just shell scope — is its own topic in this track when it's ready.
