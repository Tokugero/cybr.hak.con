#!/usr/bin/env bash
# Seed a temp HOME with known fake credentials. (macOS)
# Sourced by run.sh — not run directly.
#
# Same logic as the Linux version. Mac-specific seeding (Keychain
# entries) isn't done here because creating Keychain items requires
# interactive prompts and isn't testable in a non-interactive harness.

set -euo pipefail

TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/cred-scrub-test-XXXXXX")
export HOME="$TEST_HOME"

# ── Env vars ──
export AWS_ACCESS_KEY_ID="TEST_AKIA_FAKE"
export AWS_SECRET_ACCESS_KEY="TEST_FAKE_SECRET"
export AWS_PROFILE="TEST_profile"
export AWS_REGION="us-fake-1"

export GOOGLE_APPLICATION_CREDENTIALS="$TEST_HOME/fake-gcp.json"
export GCLOUD_PROJECT="fake-project"
export CLOUDSDK_CORE_PROJECT="fake-project"

export AZURE_CLIENT_ID="TEST_FAKE_AZURE_CLIENT"
export AZURE_TENANT_ID="TEST_FAKE_AZURE_TENANT"
export ARM_SUBSCRIPTION_ID="TEST_FAKE_ARM"

export TF_TOKEN_app_terraform_io="TEST_FAKE_TF"
export TF_VAR_secret="TEST_FAKE_TFVAR"

export KUBECONFIG="$TEST_HOME/fake-kube.yaml"
export TALOSCONFIG="$TEST_HOME/fake-talos.yaml"
export PULUMI_ACCESS_TOKEN="TEST_FAKE_PULUMI"

export GITHUB_TOKEN="TEST_FAKE_GH"
export GITLAB_TOKEN="TEST_FAKE_GL"

export ANTHROPIC_API_KEY="TEST_FAKE_ANTHROPIC"
export OPENAI_API_KEY="TEST_FAKE_OPENAI"

export NPM_TOKEN="TEST_FAKE_NPM"
export CARGO_REGISTRY_TOKEN="TEST_FAKE_CARGO"

export VAULT_TOKEN="TEST_FAKE_VAULT"
export VAULT_ADDR="https://test.example/"

export DOCKER_HOST="tcp://test.example:2375"
export CF_API_TOKEN="TEST_FAKE_CF"
export NETLIFY_AUTH_TOKEN="TEST_FAKE_NETLIFY"
export VERCEL_TOKEN="TEST_FAKE_VERCEL"

export SLACK_TOKEN="TEST_FAKE_SLACK"
export SENDGRID_API_KEY="TEST_FAKE_SG"
export DATADOG_API_KEY="TEST_FAKE_DD"

# ── Dotfiles ──
mkdir -p "$TEST_HOME/.aws"
cat > "$TEST_HOME/.aws/credentials" <<'EOF'
[default]
aws_access_key_id = TEST_AKIA_FAKE_DOTFILE
aws_secret_access_key = TEST_FAKE_SECRET_DOTFILE
EOF

mkdir -p "$TEST_HOME/.config/gcloud"
echo "fake gcp config" > "$TEST_HOME/.config/gcloud/active_config"

mkdir -p "$TEST_HOME/.kube"
echo "fake kubeconfig" > "$TEST_HOME/.kube/config"

mkdir -p "$TEST_HOME/.docker"
echo '{"auths":{}}' > "$TEST_HOME/.docker/config.json"

mkdir -p "$TEST_HOME/.ssh"
echo "fake ssh private key" > "$TEST_HOME/.ssh/id_ed25519"
chmod 600 "$TEST_HOME/.ssh/id_ed25519"

# Fake SSH agent socket — just a regular file
touch "$TEST_HOME/fake-ssh-sock"
export SSH_AUTH_SOCK="$TEST_HOME/fake-ssh-sock"

# Fake macOS Keychain location (only the file presence is checked, so
# this is enough to make the probe report "present")
mkdir -p "$TEST_HOME/Library/Keychains"
echo "fake keychain bytes" > "$TEST_HOME/Library/Keychains/login.keychain-db"

echo "Test HOME seeded at: $TEST_HOME" >&2
