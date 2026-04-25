# Credential probe — what's reachable from this PowerShell session? (Windows)
#
# Read-only. Doesn't modify anything. Walks credential categories (env
# vars, dotfiles, agents, default-path redirects, Credential Manager)
# and prints a fixed-width report suitable for diffing.
#
# Output format: three columns separated by " | ".
#   Category               | Status     | Source / notes
#
# Status values:
#   exposed     - credential value reachable from this session
#   present     - file or directory exists on disk
#   active      - agent or service running
#   default     - config-redirect env var unset; tool reads disk default
#   redirected  - config-redirect env var points at NUL or empty dir
#   set         - config-redirect env var set to an explicit path
#   clean       - nothing in this category
#   n/a         - not applicable / tool not installed
#
# This script never prints credential VALUES - only variable names,
# file paths, counts, and process states.
#
# NOT YET VERIFIED on a clean Windows machine. See notes.md for the
# specific behaviors to confirm before relying on this on stage.

$ErrorActionPreference = 'Continue'

# Names of env vars that are path redirects, not credential values.
# Excluded from the credential-env-var check so KUBECONFIG=NUL doesn't
# count as an exposed Kubernetes credential.
$RedirectVars = @(
    'AWS_CONFIG_FILE','AWS_SHARED_CREDENTIALS_FILE','KUBECONFIG','TALOSCONFIG',
    'TF_CLI_CONFIG_FILE','SOPS_AGE_KEY_FILE','NPM_CONFIG_USERCONFIG',
    'GIT_CONFIG_GLOBAL','CLOUDSDK_CONFIG','AZURE_CONFIG_DIR',
    'DOCKER_CONFIG','CARGO_HOME','PULUMI_HOME'
)

function Write-Row {
    param([string]$Category, [string]$Status, [string]$Notes)
    "{0,-25} | {1,-10} | {2}" -f $Category, $Status, $Notes
}

function Write-RowHeader {
    Write-Row 'Category' 'Status' 'Source / notes'
    "{0} | {1} | {2}" -f ('-' * 25), ('-' * 10), ('-' * 14)
}

function Get-EnvVarsMatching {
    param([string]$Pattern)
    Get-ChildItem env: |
        Where-Object { $_.Name -match "^($Pattern)" -and $RedirectVars -notcontains $_.Name } |
        Select-Object -ExpandProperty Name | Sort-Object
}

function Test-EnvCategory {
    param([string]$Label, [string]$Pattern)
    $vars = @(Get-EnvVarsMatching $Pattern)
    if ($vars.Count -gt 0) {
        $names = ($vars | Select-Object -First 3) -join ','
        if ($vars.Count -gt 3) {
            Write-Row $Label 'exposed' "$($vars.Count) vars: $names, ..."
        } else {
            Write-Row $Label 'exposed' "$($vars.Count) vars: $names"
        }
    } else {
        Write-Row $Label 'clean' '-'
    }
}

function Test-DotPath {
    param([string]$Label, [string]$Path)
    if (Test-Path $Path) {
        Write-Row $Label 'present' $Path
    } else {
        Write-Row $Label 'clean' '-'
    }
}

function Test-Redirect {
    param([string]$Label, [string]$VarName)
    $value = (Get-Item "env:$VarName" -ErrorAction SilentlyContinue).Value
    if ([string]::IsNullOrEmpty($value)) {
        Write-Row $Label 'default' "$VarName unset; tool reads disk default"
    } elseif ($value -in @('NUL','nul','/dev/null')) {
        Write-Row $Label 'redirected' "$VarName=$value"
    } elseif ((Test-Path $value -PathType Container -ErrorAction SilentlyContinue) -and -not (Get-ChildItem $value -ErrorAction SilentlyContinue)) {
        Write-Row $Label 'redirected' "$VarName=$value (empty dir)"
    } else {
        Write-Row $Label 'set' "$VarName=$value"
    }
}

# ── Header ──
"=== Credential Probe (Windows) ==="
"Profile: $env:USERPROFILE"
"Date: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')"
""
Write-RowHeader

$home_dir = $env:USERPROFILE

# ── Cloud env ──
Test-EnvCategory 'AWS env vars'   'AWS_'
Test-EnvCategory 'GCP env vars'   'GOOGLE_|GCLOUD_|CLOUDSDK_'
Test-EnvCategory 'Azure env vars' 'AZURE_|ARM_'

# ── Cloud dotfiles ──
Test-DotPath 'AWS config'   "$home_dir\.aws"
Test-DotPath 'GCP config'   "$env:APPDATA\gcloud"
Test-DotPath 'Azure config' "$home_dir\.azure"

# ── Infrastructure ──
Test-EnvCategory 'Terraform tokens' 'TERRAFORM_TOKEN|TF_TOKEN|TF_VAR|TF_CLI'
Test-EnvCategory 'Kubernetes'       'KUBECONFIG|KUBE_TOKEN|KUBE_CONTEXT|KUBERNETES_'
Test-EnvCategory 'Talos'            'TALOSCONFIG'
Test-EnvCategory 'Pulumi'           'PULUMI_'
Test-DotPath 'Kubeconfig'      "$home_dir\.kube\config"
Test-DotPath 'Terraform creds' "$env:APPDATA\terraform.d\credentials.tfrc.json"
Test-DotPath 'Pulumi creds'    "$home_dir\.pulumi\credentials.json"

# ── VCS ──
Test-EnvCategory 'Git tokens' 'GITHUB_|GH_TOKEN|GITLAB_|BITBUCKET_'
Test-DotPath '.git-credentials' "$home_dir\.git-credentials"
Test-DotPath '_netrc'           "$home_dir\_netrc"
Test-DotPath 'gh CLI config'    "$env:APPDATA\GitHub CLI"

# ── LLM API keys ──
Test-EnvCategory 'LLM API keys' '(ANTHROPIC|OPENAI|GOOGLE_API|GEMINI|MISTRAL|COHERE|GROQ|TOGETHER|REPLICATE)_API'

# ── Package registries ──
Test-EnvCategory 'Pkg registry tokens' 'NPM_TOKEN|CARGO_REGISTRY|PYPI_TOKEN|NUGET_API_KEY'
Test-DotPath '.npmrc'      "$home_dir\.npmrc"
Test-DotPath 'Cargo creds' "$home_dir\.cargo\credentials.toml"

# ── Secrets managers ──
Test-EnvCategory 'Vault' 'VAULT_'
Test-DotPath 'SOPS age key' "$env:APPDATA\sops\age\keys.txt"

# ── Containers ──
Test-EnvCategory 'Docker env' 'DOCKER_|CONTAINER_HOST'
Test-DotPath 'Docker config' "$home_dir\.docker\config.json"

# ── Hosting/CDN ──
Test-EnvCategory 'Cloudflare'     'CF_API'
Test-EnvCategory 'Netlify/Vercel' 'NETLIFY_|VERCEL_'

# ── Misc ──
Test-EnvCategory 'Slack/SendGrid/DD' 'SLACK_|SENDGRID_|DATADOG_'

# ── Default-path redirects ──
Test-Redirect 'AWS shared creds'   'AWS_SHARED_CREDENTIALS_FILE'
Test-Redirect 'AWS config file'    'AWS_CONFIG_FILE'
Test-Redirect 'Kubeconfig'         'KUBECONFIG'
Test-Redirect 'Talos config'       'TALOSCONFIG'
Test-Redirect 'Terraform CLI cfg'  'TF_CLI_CONFIG_FILE'
Test-Redirect 'SOPS age key'       'SOPS_AGE_KEY_FILE'
Test-Redirect 'npm user config'    'NPM_CONFIG_USERCONFIG'
Test-Redirect 'Global git config'  'GIT_CONFIG_GLOBAL'
Test-Redirect 'GCP config dir'     'CLOUDSDK_CONFIG'
Test-Redirect 'Azure config dir'   'AZURE_CONFIG_DIR'
Test-Redirect 'Docker config dir'  'DOCKER_CONFIG'
Test-Redirect 'Cargo home'         'CARGO_HOME'
Test-Redirect 'Pulumi home'        'PULUMI_HOME'

# ── SSH agent (Windows OpenSSH) ──
$ssh_service = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($ssh_service -and $ssh_service.Status -eq 'Running') {
    $loaded = 0
    try {
        $output = & ssh-add -l 2>$null
        $loaded = @($output | Where-Object { $_ -and $_ -notmatch 'no identities' }).Count
    } catch {}
    Write-Row 'SSH agent' 'active' "ssh-agent service running ($loaded keys)"
} else {
    Write-Row 'SSH agent' 'clean' '-'
}

# ── SSH private keys ──
$ssh_dir = "$home_dir\.ssh"
if (Test-Path $ssh_dir -PathType Container) {
    $keys = @(Get-ChildItem $ssh_dir -File -Filter 'id_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.pub' })
    if ($keys.Count -gt 0) {
        Write-Row 'SSH private keys' 'present' "$($keys.Count) file(s) in ~/.ssh"
    } else {
        Write-Row 'SSH private keys' 'clean' '-'
    }
} else {
    Write-Row 'SSH private keys' 'clean' '-'
}

# ── GPG agent (gpg4win or scoop install gnupg) ──
$gpg = Get-Command gpg-connect-agent -ErrorAction SilentlyContinue
if ($gpg) {
    & gpg-connect-agent /bye 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Row 'GPG agent' 'active' 'gpg-agent reachable'
    } else {
        Write-Row 'GPG agent' 'clean' '-'
    }
} else {
    Write-Row 'GPG agent' 'n/a' 'gpg not installed'
}

# ── Windows Credential Manager ──
$cmdkey = Get-Command cmdkey -ErrorAction SilentlyContinue
if ($cmdkey) {
    try {
        $entries = @(& cmdkey /list 2>$null | Where-Object { $_ -match 'Target:' })
        if ($entries.Count -gt 0) {
            Write-Row 'Credential Manager' 'present' "$($entries.Count) entries (cmdkey /list)"
        } else {
            Write-Row 'Credential Manager' 'clean' 'no entries'
        }
    } catch {
        Write-Row 'Credential Manager' 'clean' '-'
    }
} else {
    Write-Row 'Credential Manager' 'n/a' 'cmdkey not available'
}

""
"Done."
