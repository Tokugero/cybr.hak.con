# Seed a temp HOME with known fake credentials. (Windows)
# Sourced by run.ps1.
#
# Mirrors the Linux/Mac seed.sh logic. All values are bogus and prefixed
# with TEST_ to make accidental leakage obvious.
#
# After sourcing:
#   $env:USERPROFILE points to a temp directory with fake config dirs.
#   Common credential env vars are set with fake values.
#
# NOT YET VERIFIED on a clean Windows machine.

$rand = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$TEST_HOME = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "cred-scrub-test-$rand") -Force

$env:USERPROFILE = $TEST_HOME.FullName
$env:APPDATA = Join-Path $TEST_HOME.FullName 'AppData\Roaming'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

# ── Env vars ──
$env:AWS_ACCESS_KEY_ID = 'TEST_AKIA_FAKE'
$env:AWS_SECRET_ACCESS_KEY = 'TEST_FAKE_SECRET'
$env:AWS_PROFILE = 'TEST_profile'
$env:AWS_REGION = 'us-fake-1'

$env:GOOGLE_APPLICATION_CREDENTIALS = "$($TEST_HOME.FullName)\fake-gcp.json"
$env:GCLOUD_PROJECT = 'fake-project'
$env:CLOUDSDK_CORE_PROJECT = 'fake-project'

$env:AZURE_CLIENT_ID = 'TEST_FAKE_AZURE_CLIENT'
$env:AZURE_TENANT_ID = 'TEST_FAKE_AZURE_TENANT'
$env:ARM_SUBSCRIPTION_ID = 'TEST_FAKE_ARM'

$env:TF_TOKEN_app_terraform_io = 'TEST_FAKE_TF'
$env:TF_VAR_secret = 'TEST_FAKE_TFVAR'

$env:KUBECONFIG = "$($TEST_HOME.FullName)\fake-kube.yaml"
$env:TALOSCONFIG = "$($TEST_HOME.FullName)\fake-talos.yaml"
$env:PULUMI_ACCESS_TOKEN = 'TEST_FAKE_PULUMI'

$env:GITHUB_TOKEN = 'TEST_FAKE_GH'
$env:GITLAB_TOKEN = 'TEST_FAKE_GL'

$env:ANTHROPIC_API_KEY = 'TEST_FAKE_ANTHROPIC'
$env:OPENAI_API_KEY = 'TEST_FAKE_OPENAI'

$env:NPM_TOKEN = 'TEST_FAKE_NPM'
$env:CARGO_REGISTRY_TOKEN = 'TEST_FAKE_CARGO'

$env:VAULT_TOKEN = 'TEST_FAKE_VAULT'
$env:VAULT_ADDR = 'https://test.example/'

$env:DOCKER_HOST = 'tcp://test.example:2375'
$env:CF_API_TOKEN = 'TEST_FAKE_CF'
$env:NETLIFY_AUTH_TOKEN = 'TEST_FAKE_NETLIFY'
$env:VERCEL_TOKEN = 'TEST_FAKE_VERCEL'

$env:SLACK_TOKEN = 'TEST_FAKE_SLACK'
$env:SENDGRID_API_KEY = 'TEST_FAKE_SG'
$env:DATADOG_API_KEY = 'TEST_FAKE_DD'

# ── Dotfiles / config dirs ──
$awsDir = Join-Path $TEST_HOME.FullName '.aws'
New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
@'
[default]
aws_access_key_id = TEST_AKIA_FAKE_DOTFILE
aws_secret_access_key = TEST_FAKE_SECRET_DOTFILE
'@ | Set-Content -Path (Join-Path $awsDir 'credentials')

New-Item -ItemType Directory -Path (Join-Path $env:APPDATA 'gcloud') -Force | Out-Null
'fake gcp config' | Set-Content -Path (Join-Path $env:APPDATA 'gcloud\active_config')

New-Item -ItemType Directory -Path (Join-Path $TEST_HOME.FullName '.kube') -Force | Out-Null
'fake kubeconfig' | Set-Content -Path (Join-Path $TEST_HOME.FullName '.kube\config')

New-Item -ItemType Directory -Path (Join-Path $TEST_HOME.FullName '.docker') -Force | Out-Null
'{"auths":{}}' | Set-Content -Path (Join-Path $TEST_HOME.FullName '.docker\config.json')

New-Item -ItemType Directory -Path (Join-Path $TEST_HOME.FullName '.ssh') -Force | Out-Null
'fake ssh private key' | Set-Content -Path (Join-Path $TEST_HOME.FullName '.ssh\id_ed25519')

Write-Host "Test HOME seeded at: $($TEST_HOME.FullName)"
