# Scoped credential injection patterns

Cred-scrub showed how to *remove* broad credentials. This file walks the other half of the Tier 0 pattern: how to put narrow, scoped credentials *back* inside the perimeter, so you can do legitimate work without leaving your prod tokens in scope.

These are descriptions of real-world patterns, not runnable steps. Some require paid accounts (AWS, hosted Kubernetes, 1Password) to actually use; the *shape* of the pattern is the lesson, and you can read the lesson without an account.

Each pattern shows roughly what the relevant snippet looks like inside an `.envrc`. The full setup (creating the role, configuring the profile, registering with the secrets manager) lives in the documentation of the underlying tool, which we link rather than duplicate.

---

## Pattern 1 — `.envrc` + `.envrc.local`

The cleanest separation of concerns:

- `.envrc` — committed. Defines the *shape* of the perimeter: which env vars get set, what redirects apply, the sentinels for the fingerprint script. Anyone who clones the repo gets the shape.
- `.envrc.local` — gitignored. Holds machine-specific values: API keys, profile names, paths.

In the committed `.envrc`:

```sh
log_status "perimeter active"
export PERIMETER_NAME=engagement-x
export AWS_REGION=us-east-2
# ... shape of the perimeter ...

# Source local secrets last; .envrc.local is gitignored
dotenv_if_exists .envrc.local
```

In the gitignored `.envrc.local` (per-developer):

```sh
export AWS_PROFILE=engagement-x-readonly
export GITHUB_TOKEN=ghp_…
```

**Why this is useful.** A teammate clones the repo and gets the perimeter's shape immediately. They drop in their own `.envrc.local` (perhaps copied from `.envrc.local.example`) with their own scoped credentials. Nobody's secrets get committed by accident.

**Honest limit.** `.envrc.local` is plaintext on disk. Anything that can read your home directory can read it. For agents, this means *the agent can still cat `.envrc.local` even when the perimeter is active.* For static threats (a leaked dev laptop, a backup with the file), use one of the patterns below.

---

## Pattern 2 — `aws-vault exec` (or similar)

[`aws-vault`](https://github.com/99designs/aws-vault) stores AWS credentials in your OS keychain (encrypted at rest, requires a passphrase or biometric to unlock), then issues short-lived AssumeRole tokens for your use. Free, popular, fits the dependency floor.

In the `.envrc`:

```sh
# Fetch short-lived AssumeRole credentials for the engagement profile.
# The role policy in IAM should grant only what this engagement needs.
eval "$(aws-vault exec engagement-x --json | jq -r '
  "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)
   export AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)
   export AWS_SESSION_TOKEN=\(.SessionToken)"
')"
```

Or simpler if you launch tools through aws-vault directly:

```sh
# Define a wrapper rather than exporting creds into the shell
alias aws='aws-vault exec engagement-x -- aws'
alias terraform='aws-vault exec engagement-x -- terraform'
```

**Why this is useful.** Long-lived access keys (`AKIA…`) are never on disk in plaintext. The session-bound credentials live for ~1 hour, in env vars, scoped to whatever the role's IAM policy allows. If your laptop is stolen mid-session, the attacker has at most an hour of read-only access.

**Honest limit.** The session token is in your environment while you're working. A poisoned context running inside the perimeter can still exfil it. The point is *less time and less scope*, not no exposure.

---

## Pattern 3 — Per-directory Kubernetes contexts

Most people have a single `~/.kube/config` with cluster-admin context for every cluster they touch. That's the wrong default for an agent perimeter.

Instead, give the directory its own kubeconfig pointing at a narrowly-scoped service account:

```sh
# Project-local kubeconfig — narrow service account, namespace-scoped role
export KUBECONFIG=$PWD/.kubeconfig

# Or fetch a fresh service-account token from a secrets manager
KUBECONFIG=$(mktemp)
export KUBECONFIG
trap 'rm -f "$KUBECONFIG"' EXIT
aws-vault exec eks-readonly -- aws eks update-kubeconfig \
  --name engagement-cluster --kubeconfig "$KUBECONFIG"
```

The `.kubeconfig` file has a service account token bound to a namespace and a `Role` (not `ClusterRole`) that allows only the operations this work needs. `kubectl` (or any tool that respects `KUBECONFIG`) finds this file and only this file.

**Why this is useful.** An agent given a "fix this YAML" task has no path to your other clusters or to cluster-admin verbs. If it tries `kubectl get nodes`, it gets `Forbidden` instead of a list.

**Honest limit.** Service account tokens are static (don't expire by default). Rotate them per-engagement, or use OIDC-issued tokens with TTLs. Either way, the kubeconfig file itself is plaintext on disk; same caveat as `.envrc.local`.

---

## Pattern 4 — Short-lived secrets from a manager

When the credential needs to be live (not the long-lived seed), fetch it on perimeter entry:

```sh
# HashiCorp Vault — issue a short-lived database credential
DB_CREDS=$(vault read -format=json database/creds/engagement-x)
export DB_USERNAME=$(echo "$DB_CREDS" | jq -r '.data.username')
export DB_PASSWORD=$(echo "$DB_CREDS" | jq -r '.data.password')

# 1Password CLI — fetch a tagged secret without putting it on disk
export GITHUB_TOKEN=$(op read "op://engagements/x/github-pat")

# sops-encrypted .env — encrypted on disk, decrypted into the shell
eval "$(sops -d .env.enc)"
```

Each of these has a different threat model and tool dependency. Pick whichever fits how you already manage secrets. The pattern is the same: **don't bake long-lived credentials into your shell rc; fetch a scoped one when you enter the perimeter, drop it when you leave.**

**Why this is useful.** If something exfils the credential, the credential is short-lived; the blast radius shrinks naturally. The directory perimeter even enforces a kind of dwell-time limit: as soon as you `cd` out, direnv unloads the env and the next `cd` back in re-fetches.

**Honest limit.** During the dwell time, the credential is in your environment, same as Pattern 2's. The attacker doesn't need long-lived access; they need *now*. This pattern reduces *passive* exposure (a backup, a stolen laptop later) more than active.

---

## Composing patterns

Real perimeters combine these. A typical engagement `.envrc`:

```sh
log_status "perimeter active for engagement-x"

# Sentinel
export PERIMETER_ACTIVE=yes
export PERIMETER_NAME=engagement-x

# Pattern 1: source machine-specific secrets
dotenv_if_exists .envrc.local

# Pattern 2: scoped AWS creds via aws-vault
alias aws='aws-vault exec engagement-x -- aws'

# Pattern 3: scoped k8s context
export KUBECONFIG=$PWD/.kubeconfig

# Pattern 4: short-lived GitHub PAT for this engagement
export GITHUB_TOKEN=$(op read "op://engagements/x/github-pat" 2>/dev/null || echo "")
```

That's a perimeter that gives the agent exactly the credentials it needs for the engagement, and nothing else.

---

## What none of these patterns address

- **Malicious code reading process memory.** None of these stop a process inside the perimeter from `cat /proc/self/environ`. Tier 1+ is needed for that.
- **Network egress.** A scoped credential is still useful to an attacker who can exfil it before the TTL expires. Pair these patterns with a network egress control if S1 is the threat.
- **Compromise of the underlying tool.** If `aws-vault` itself is compromised, all bets are off. Same for 1Password CLI, Vault, sops. Treat the chain of trust seriously.

These limits are why the talk's "composition" framing matters: Tier 0 patterns are *components* of safer setups, not full answers. The reason to use them is they cost almost nothing and pay back across all the higher tiers you might layer on.
