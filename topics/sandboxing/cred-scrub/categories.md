# Credential categories

What every platform's probe and scrubber covers. Implementations differ across Mac, Linux, and Windows; the *categories* are the same so the cross-platform comparison stays honest.

## Layer 1: credential values to unset

These are env vars that hold a credential value (token, key, secret, profile selector). The scrubber unsets them. The probe reports them as `exposed` if any are set, or `clean` if not.

### Cloud providers

| Category | Env vars | Config location on disk |
|----------|----------|-------------------------|
| AWS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_PROFILE`, `AWS_DEFAULT_PROFILE`, `AWS_REGION` | `~/.aws/` (Mac/Linux), `%USERPROFILE%\.aws\` (Windows) |
| GCP | `GOOGLE_APPLICATION_CREDENTIALS`, `GCLOUD_PROJECT`, `GOOGLE_CLOUD_PROJECT`, anything starting with `CLOUDSDK_` | `~/.config/gcloud/` (Mac/Linux), `%APPDATA%\gcloud\` (Windows) |
| Azure | anything starting with `AZURE_` or `ARM_` | `~/.azure/` (Mac/Linux), `%USERPROFILE%\.azure\` (Windows) |

### Infrastructure tooling

| Category | Env vars | Config location on disk |
|----------|----------|-------------------------|
| Terraform / OpenTofu | `TERRAFORM_TOKEN`, anything starting with `TF_TOKEN_` or `TF_VAR_` | `~/.terraformrc`, `~/.terraform.d/credentials.tfrc.json` |
| Kubernetes | `KUBE_TOKEN`, `KUBE_CONTEXT`, `KUBERNETES_SERVICE_HOST`, `KUBERNETES_SERVICE_PORT` | `~/.kube/config` |
| Talos | (no value-only vars; use Layer 2 redirect) | `~/.talos/` |
| Pulumi | `PULUMI_ACCESS_TOKEN`, `PULUMI_CONFIG_PASSPHRASE` | `~/.pulumi/credentials.json` |

### Source control and package registries

| Category | Env vars | Config location on disk |
|----------|----------|-------------------------|
| Git providers | `GITHUB_TOKEN`, `GH_TOKEN`, `GITLAB_TOKEN`, `GITLAB_PAT`, `BITBUCKET_TOKEN` | `~/.git-credentials`, `~/.netrc`, `~/.config/gh/`, `~/.config/glab-cli/` |
| Package registries | `NPM_TOKEN`, `CARGO_REGISTRY_TOKEN`, `PYPI_TOKEN`, `NUGET_API_KEY` | `~/.npmrc`, `~/.cargo/credentials.toml`, `~/.pypirc` |

### LLM API keys

| Category | Env vars |
|----------|----------|
| Common LLM keys | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `GEMINI_API_KEY`, `MISTRAL_API_KEY`, `COHERE_API_KEY`, `GROQ_API_KEY`, `TOGETHER_API_KEY`, `REPLICATE_API_TOKEN` |

### Secrets managers

| Category | Env vars |
|----------|----------|
| HashiCorp Vault | `VAULT_TOKEN`, `VAULT_ADDR`, `VAULT_NAMESPACE` |

### Container / registry tooling (value vars)

| Category | Env vars |
|----------|----------|
| Docker | `DOCKER_HOST`, `DOCKER_TLS_VERIFY`, `DOCKER_CERT_PATH`, `CONTAINER_HOST` |

### Hosting and CDN

| Category | Env vars |
|----------|----------|
| Cloudflare | `CF_API_TOKEN`, `CF_API_KEY` |
| Netlify | `NETLIFY_AUTH_TOKEN` |
| Vercel | `VERCEL_TOKEN` |

### Miscellaneous

| Category | Env vars |
|----------|----------|
| Slack | `SLACK_TOKEN`, `SLACK_WEBHOOK_URL` |
| SendGrid | `SENDGRID_API_KEY` |
| Datadog | `DATADOG_API_KEY` |

---

## Layer 2: default-path redirects

These env vars override default disk-config locations. When unset, the tool reads the default disk path on its own. Setting them to `/dev/null` (file-based) or to an empty directory (directory-based) actively prevents that fallback. The probe reports them as `default` when unset, `redirected` when pointing at `/dev/null` or an empty directory, or `set` when pointing at some other path.

### File-based redirects

| Tool | Env var | Default path the var overrides |
|------|---------|--------------------------------|
| AWS CLI | `AWS_CONFIG_FILE` | `~/.aws/config` |
| AWS CLI | `AWS_SHARED_CREDENTIALS_FILE` | `~/.aws/credentials` |
| Kubernetes | `KUBECONFIG` | `~/.kube/config` |
| Talos | `TALOSCONFIG` | `~/.talos/config` |
| Terraform | `TF_CLI_CONFIG_FILE` | `~/.terraformrc` |
| SOPS | `SOPS_AGE_KEY_FILE` | `~/.config/sops/age/keys.txt` |
| npm | `NPM_CONFIG_USERCONFIG` | `~/.npmrc` |
| Git | `GIT_CONFIG_GLOBAL` | `~/.gitconfig` (and global credential helper) |

### Directory-based redirects

| Tool | Env var | Default directory the var overrides |
|------|---------|-------------------------------------|
| GCP | `CLOUDSDK_CONFIG` | `~/.config/gcloud/` |
| Azure | `AZURE_CONFIG_DIR` | `~/.azure/` |
| Docker | `DOCKER_CONFIG` | `~/.docker/` |
| Cargo | `CARGO_HOME` | `~/.cargo/` |
| Pulumi | `PULUMI_HOME` | `~/.pulumi/` |

On Windows, the equivalent of `/dev/null` is `NUL` (used for file-based redirects). Empty directories work the same way.

---

## Agents and sockets

| Category | What the probe checks |
|----------|----------------------|
| SSH agent | `SSH_AUTH_SOCK` set and pointing at a live socket; key count via `ssh-add -l` |
| GPG agent | Whether `gpg-agent` is reachable |
| SSH private keys | Files in `~/.ssh/id_*` (excluding `.pub`) |

The scrubber unsets `SSH_AUTH_SOCK`. It does not stop GPG agent or remove SSH key files from disk.

---

## OS keystores

Differ across platforms; each platform's `notes.md` has details.

| Platform | Keystore |
|----------|----------|
| Linux | GNOME Keyring, KWallet, `pass` |
| Mac | Keychain (login + any third-party) |
| Windows | Credential Manager, DPAPI |

The Tier 0 scrubber doesn't disconnect your shell from these keystores. That's a Tier 1+ problem (process-level isolation that prevents D-Bus / Keychain / DPAPI access).

---

## What this list isn't

- Application-specific secrets in app config files (browser cookies, password managers, IDE secret stores). Out of scope for a Tier 0 shell-environment scrubber.
- Process memory of currently-running tools. If a browser is logged in elsewhere, scrubbing your shell doesn't affect it.
- Files in arbitrary user-chosen locations. If you keep AWS credentials in `~/Desktop/secrets.txt`, that's a separate OPSEC issue.
