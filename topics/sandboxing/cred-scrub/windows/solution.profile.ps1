# Credential scrubber - Tier 0 hygiene for AI coding agents (Windows PowerShell)
#
# Two layers, same idea as the Linux/Mac scrubbers:
#   1. Remove credential values from this PowerShell session's environment.
#   2. Redirect default config paths so tools can't fall back to disk.
#
# To use, dot-source this file before running your agent in this directory:
#
#     . .\solution.profile.ps1
#
# If you have direnv installed for PowerShell (see notes.md), the
# direnv hook can apply a `.envrc` automatically. Direct sourcing is the
# default for this workshop because direnv on native Windows isn't yet
# universal.
#
# This is Tier 0 hygiene. It does NOT prevent code already running with
# elevated access from reading credential files directly, and it does
# NOT disconnect this session from Windows Credential Manager or DPAPI-
# protected secrets. See notes.md and ../discussion.md for what this misses.
#
# NOT YET VERIFIED on a clean Windows machine. See notes.md.

Write-Host "[scrubber] credential scrubber active for this PowerShell session"

# ────────────────────────────────────────────────────────────────────
# Layer 1 - unset credential values
# ────────────────────────────────────────────────────────────────────

$cred_vars = @(
    # AWS
    'AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_SESSION_TOKEN',
    'AWS_PROFILE','AWS_DEFAULT_PROFILE','AWS_REGION','AWS_DEFAULT_REGION',
    # GCP
    'GOOGLE_APPLICATION_CREDENTIALS','GCLOUD_PROJECT','GOOGLE_CLOUD_PROJECT',
    # Infrastructure (value vars only; path vars handled in Layer 2)
    'TERRAFORM_TOKEN','KUBE_TOKEN','KUBE_CONTEXT',
    'KUBERNETES_SERVICE_HOST','KUBERNETES_SERVICE_PORT',
    'PULUMI_ACCESS_TOKEN','PULUMI_CONFIG_PASSPHRASE',
    # Source control
    'GITHUB_TOKEN','GH_TOKEN','GITLAB_TOKEN','GITLAB_PAT','BITBUCKET_TOKEN',
    # LLM API keys
    'ANTHROPIC_API_KEY','OPENAI_API_KEY','GOOGLE_API_KEY','GEMINI_API_KEY',
    'MISTRAL_API_KEY','COHERE_API_KEY','GROQ_API_KEY',
    'TOGETHER_API_KEY','REPLICATE_API_TOKEN',
    # Package registries
    'NPM_TOKEN','CARGO_REGISTRY_TOKEN','PYPI_TOKEN','NUGET_API_KEY',
    # Secrets managers
    'VAULT_TOKEN','VAULT_ADDR','VAULT_NAMESPACE',
    # Container/registry tooling (value vars only)
    'DOCKER_HOST','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','CONTAINER_HOST',
    # Hosting / CDN
    'NETLIFY_AUTH_TOKEN','VERCEL_TOKEN','CF_API_TOKEN','CF_API_KEY',
    # Misc
    'SLACK_TOKEN','SLACK_WEBHOOK_URL','SENDGRID_API_KEY','DATADOG_API_KEY',
    # SSH agent socket
    'SSH_AUTH_SOCK'
)

foreach ($v in $cred_vars) {
    Remove-Item "env:$v" -ErrorAction SilentlyContinue
}

# Prefix-based unsets (CLOUDSDK_*, AZURE_*, ARM_*, TF_TOKEN_*, TF_VAR_*)
Get-ChildItem env: |
    Where-Object { $_.Name -match '^(CLOUDSDK_|AZURE_|ARM_|TF_TOKEN_|TF_VAR_)' } |
    ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }

# ────────────────────────────────────────────────────────────────────
# Layer 2 - redirect default config paths so tools can't fall back
# ────────────────────────────────────────────────────────────────────
# Without this layer, kubectl reads %USERPROFILE%\.kube\config, talosctl
# reads ~\.talos\config, aws CLI reads ~\.aws\credentials, etc., even
# when the corresponding env vars are unset. Layer 2 points these env
# vars at empty locations.

# File-based redirects
# NUL is the Windows null device, analogous to /dev/null on Unix.
$env:AWS_CONFIG_FILE = 'NUL'
$env:AWS_SHARED_CREDENTIALS_FILE = 'NUL'
$env:KUBECONFIG = 'NUL'
$env:TALOSCONFIG = 'NUL'
$env:TF_CLI_CONFIG_FILE = 'NUL'
$env:SOPS_AGE_KEY_FILE = 'NUL'
$env:NPM_CONFIG_USERCONFIG = 'NUL'
$env:GIT_CONFIG_GLOBAL = 'NUL'

# Directory-based redirects (one shared empty parent, with named subdirs)
$rand = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$scrub_empty = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "cred-scrub-empty-$rand") -Force
foreach ($sub in 'gcloud','azure','docker','cargo','pulumi') {
    New-Item -ItemType Directory -Path (Join-Path $scrub_empty.FullName $sub) -Force | Out-Null
}
$env:CLOUDSDK_CONFIG  = Join-Path $scrub_empty.FullName 'gcloud'
$env:AZURE_CONFIG_DIR = Join-Path $scrub_empty.FullName 'azure'
$env:DOCKER_CONFIG    = Join-Path $scrub_empty.FullName 'docker'
$env:CARGO_HOME       = Join-Path $scrub_empty.FullName 'cargo'
$env:PULUMI_HOME      = Join-Path $scrub_empty.FullName 'pulumi'
