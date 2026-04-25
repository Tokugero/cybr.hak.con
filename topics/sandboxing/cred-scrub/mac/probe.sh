#!/usr/bin/env bash
# Credential probe — what's reachable from this shell? (macOS)
#
# Read-only. Doesn't modify anything. Walks credential categories (env
# vars, dotfiles, agents, default-path redirects, Keychain) and prints a
# fixed-width report suitable for diffing.
#
# Output format: three columns separated by ` | `.
#   Category               | Status     | Source / notes
#
# Status values:
#   exposed     — credential value reachable from this shell
#   present     — file or directory exists on disk
#   active      — agent or daemon running
#   default     — config-redirect env var unset; tool reads disk default
#   redirected  — config-redirect env var points at /dev/null or empty dir
#   set         — config-redirect env var set to an explicit path
#   clean       — nothing in this category
#   n/a         — not applicable on this platform / tool not installed
#
# Never prints credential VALUES — only variable names, file paths,
# counts, and process states.

set -uo pipefail
LC_ALL=C

print_row() {
  printf '%-25s | %-10s | %s\n' "$1" "$2" "$3"
}

print_header() {
  printf '%-25s | %-10s | %s\n' "Category" "Status" "Source / notes"
  printf '%-25s-+-%-10s-+-%s\n' "-------------------------" "----------" "--------------"
}

# Names of env vars that are path redirects, not credential values.
# Excluded from the credential-env-var check so KUBECONFIG=/dev/null
# doesn't count as an exposed Kubernetes credential.
REDIRECT_VARS='AWS_CONFIG_FILE|AWS_SHARED_CREDENTIALS_FILE|KUBECONFIG|TALOSCONFIG|TF_CLI_CONFIG_FILE|SOPS_AGE_KEY_FILE|NPM_CONFIG_USERCONFIG|GIT_CONFIG_GLOBAL|CLOUDSDK_CONFIG|AZURE_CONFIG_DIR|DOCKER_CONFIG|CARGO_HOME|PULUMI_HOME'

env_vars_matching() {
  env | cut -d= -f1 \
    | grep -E "^(${1})" 2>/dev/null \
    | grep -vE "^(${REDIRECT_VARS})$" \
    | sort
}

env_count() {
  env_vars_matching "$1" | grep -c '.' || true
}

check_env_category() {
  local label="$1" pattern="$2"
  local count
  count=$(env_count "$pattern")
  if [ "$count" -gt 0 ]; then
    local names
    names=$(env_vars_matching "$pattern" | head -3 | tr '\n' ',' | sed 's/,$//')
    if [ "$count" -gt 3 ]; then
      print_row "$label" "exposed" "$count vars: $names, ..."
    else
      print_row "$label" "exposed" "$count vars: $names"
    fi
  else
    print_row "$label" "clean" "-"
  fi
}

check_dotfile() {
  local label="$1" path="$2"
  if [ -e "$path" ]; then
    print_row "$label" "present" "$path"
  else
    print_row "$label" "clean" "-"
  fi
}

check_redirect() {
  local label="$1" varname="$2"
  local value="${!varname:-}"
  if [ -z "$value" ]; then
    print_row "$label" "default" "$varname unset; tool reads disk default"
  elif [ "$value" = "/dev/null" ]; then
    print_row "$label" "redirected" "$varname=/dev/null"
  elif [ -d "$value" ] && [ -z "$(ls -A "$value" 2>/dev/null)" ]; then
    print_row "$label" "redirected" "$varname=$value (empty dir)"
  else
    print_row "$label" "set" "$varname=$value"
  fi
}

# ── Header ──
echo "=== Credential Probe ($(uname -s)) ==="
echo "HOME=$HOME"
echo "Date: $(date +%Y-%m-%dT%H:%M:%S%z)"
echo
print_header

# ── Cloud env ──
check_env_category "AWS env vars"       "AWS_"
check_env_category "GCP env vars"       "GOOGLE_|GCLOUD_|CLOUDSDK_"
check_env_category "Azure env vars"     "AZURE_|ARM_"

# ── Cloud dotfiles ──
check_dotfile      "AWS config"         "$HOME/.aws"
check_dotfile      "GCP config"         "$HOME/.config/gcloud"
check_dotfile      "Azure config"       "$HOME/.azure"

# ── Infrastructure ──
check_env_category "Terraform tokens"   "TERRAFORM_TOKEN|TF_TOKEN|TF_VAR|TF_CLI"
check_env_category "Kubernetes"         "KUBECONFIG|KUBE_TOKEN|KUBE_CONTEXT|KUBERNETES_"
check_env_category "Talos"              "TALOSCONFIG"
check_env_category "Pulumi"             "PULUMI_"
check_dotfile      "Kubeconfig"         "$HOME/.kube/config"
check_dotfile      "Terraform creds"    "$HOME/.terraformrc"
check_dotfile      "Pulumi creds"       "$HOME/.pulumi/credentials.json"

# ── VCS ──
check_env_category "Git tokens"         "GITHUB_|GH_TOKEN|GITLAB_|BITBUCKET_"
check_dotfile      ".git-credentials"   "$HOME/.git-credentials"
check_dotfile      ".netrc"             "$HOME/.netrc"
check_dotfile      "gh CLI config"      "$HOME/.config/gh"

# ── LLM API keys ──
check_env_category "LLM API keys"       "(ANTHROPIC|OPENAI|GOOGLE_API|GEMINI|MISTRAL|COHERE|GROQ|TOGETHER|REPLICATE)_API"

# ── Package registries ──
check_env_category "Pkg registry tokens" "NPM_TOKEN|CARGO_REGISTRY|PYPI_TOKEN|NUGET_API_KEY"
check_dotfile      ".npmrc"             "$HOME/.npmrc"
check_dotfile      "Cargo creds"        "$HOME/.cargo/credentials.toml"

# ── Secrets managers ──
check_env_category "Vault"              "VAULT_"
check_dotfile      "SOPS age key"       "$HOME/.config/sops/age/keys.txt"

# ── Containers ──
check_env_category "Docker env"         "DOCKER_|CONTAINER_HOST"
check_dotfile      "Docker config"      "$HOME/.docker/config.json"

# ── Hosting/CDN ──
check_env_category "Cloudflare"         "CF_API"
check_env_category "Netlify/Vercel"     "NETLIFY_|VERCEL_"

# ── Misc ──
check_env_category "Slack/SendGrid/DD"  "SLACK_|SENDGRID_|DATADOG_"

# ── Default-path redirects ──
check_redirect "AWS shared creds"   "AWS_SHARED_CREDENTIALS_FILE"
check_redirect "AWS config file"    "AWS_CONFIG_FILE"
check_redirect "Kubeconfig"         "KUBECONFIG"
check_redirect "Talos config"       "TALOSCONFIG"
check_redirect "Terraform CLI cfg"  "TF_CLI_CONFIG_FILE"
check_redirect "SOPS age key"       "SOPS_AGE_KEY_FILE"
check_redirect "npm user config"    "NPM_CONFIG_USERCONFIG"
check_redirect "Global git config"  "GIT_CONFIG_GLOBAL"
check_redirect "GCP config dir"     "CLOUDSDK_CONFIG"
check_redirect "Azure config dir"   "AZURE_CONFIG_DIR"
check_redirect "Docker config dir"  "DOCKER_CONFIG"
check_redirect "Cargo home"         "CARGO_HOME"
check_redirect "Pulumi home"        "PULUMI_HOME"

# ── SSH agent ──
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK:-}" ]; then
  loaded=$(SSH_ASKPASS= ssh-add -l 2>/dev/null | grep -c '.' || true)
  print_row "SSH agent" "active" "$SSH_AUTH_SOCK ($loaded keys)"
else
  print_row "SSH agent" "clean" "-"
fi

# ── SSH private keys ──
if [ -d "$HOME/.ssh" ]; then
  keys=$(find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' 2>/dev/null | grep -c '.' || true)
  if [ "$keys" -gt 0 ]; then
    print_row "SSH private keys" "present" "$keys file(s) in ~/.ssh"
  else
    print_row "SSH private keys" "clean" "-"
  fi
else
  print_row "SSH private keys" "clean" "-"
fi

# ── GPG agent ──
if command -v gpg-connect-agent >/dev/null 2>&1; then
  if gpg-connect-agent /bye >/dev/null 2>&1; then
    print_row "GPG agent" "active" "gpg-agent reachable"
  else
    print_row "GPG agent" "clean" "-"
  fi
else
  print_row "GPG agent" "n/a" "gpg not installed"
fi

# ── macOS Keychain ──
KEYCHAIN_PATH="$HOME/Library/Keychains/login.keychain-db"
if [ -f "$KEYCHAIN_PATH" ]; then
  print_row "Login Keychain" "present" "$KEYCHAIN_PATH"
else
  # Older macOS (pre-Catalina) used login.keychain (no -db suffix)
  KEYCHAIN_OLD="$HOME/Library/Keychains/login.keychain"
  if [ -f "$KEYCHAIN_OLD" ]; then
    print_row "Login Keychain" "present" "$KEYCHAIN_OLD"
  else
    print_row "Login Keychain" "clean" "-"
  fi
fi

if command -v security >/dev/null 2>&1; then
  KEYCHAIN_COUNT=$(security list-keychains -d user 2>/dev/null | grep -c '.' || true)
  if [ "$KEYCHAIN_COUNT" -gt 1 ]; then
    print_row "Other keychains" "present" "$KEYCHAIN_COUNT keychains in user search list"
  fi
fi

echo
echo "Done."
