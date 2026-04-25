# Test harness for the Windows cred-scrub.
#
# Same shape as the Linux/Mac run.sh. Seeds a fake USERPROFILE with
# known credentials, runs the probe to baseline, applies the scrubber,
# runs the probe again, prints a pass/fail summary.
#
# Runs the seed → probe → scrub → probe sequence in a child pwsh
# process so env changes don't leak into the calling shell.
#
# NOT YET VERIFIED on a clean Windows machine. See ..\notes.md.

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TopicDir = Split-Path -Parent $ScriptDir

$baselineFile = Join-Path $ScriptDir '.baseline.txt'
$scrubbedFile = Join-Path $ScriptDir '.scrubbed.txt'

# Run everything in a child pwsh so env changes are isolated.
$childScript = @"
`$ErrorActionPreference = 'Continue'
. "$ScriptDir\seed.ps1"
try {
    Write-Host "=== baseline probe ==="
    `$baseline = & "$TopicDir\probe.ps1"
    `$baseline | Tee-Object -FilePath "$baselineFile" | Write-Host
    Write-Host ""

    Write-Host "=== applying scrubber ==="
    . "$TopicDir\solution.profile.ps1"
    Write-Host ""

    Write-Host "=== scrubbed probe ==="
    `$scrubbed = & "$TopicDir\probe.ps1"
    `$scrubbed | Tee-Object -FilePath "$scrubbedFile" | Write-Host
    Write-Host ""
} finally {
    if (`$env:USERPROFILE -and `$env:USERPROFILE.StartsWith(`$env:TEMP)) {
        Remove-Item -Recurse -Force `$env:USERPROFILE -ErrorAction SilentlyContinue
    }
}
"@

# Execute the child
$childScript | pwsh -NoProfile -Command -

# Parse and summarize from the captured files
function Count-Status {
    param([string]$Status, [string]$File)
    if (Test-Path $File) {
        @(Get-Content $File | Where-Object { $_ -match " $Status " }).Count
    } else { 0 }
}

$base_exposed = Count-Status 'exposed' $baselineFile
$scr_exposed = Count-Status 'exposed' $scrubbedFile
$base_present = Count-Status 'present' $baselineFile
$scr_present = Count-Status 'present' $scrubbedFile
$base_active = Count-Status 'active' $baselineFile
$scr_active = Count-Status 'active' $scrubbedFile
$base_default = Count-Status 'default' $baselineFile
$scr_default = Count-Status 'default' $scrubbedFile
$base_redirected = Count-Status 'redirected' $baselineFile
$scr_redirected = Count-Status 'redirected' $scrubbedFile

Write-Host "=== summary ==="
"{0,-26} | {1,8} | {2,8}" -f 'Status', 'baseline', 'scrubbed' | Write-Host
"{0}-+-{1}-+-{2}" -f ('-'*26), ('-'*8), ('-'*8) | Write-Host
"{0,-26} | {1,8} | {2,8}" -f 'exposed (env vars)',           $base_exposed,    $scr_exposed | Write-Host
"{0,-26} | {1,8} | {2,8}" -f 'present (dotfiles)',           $base_present,    $scr_present | Write-Host
"{0,-26} | {1,8} | {2,8}" -f 'active (agents)',              $base_active,     $scr_active | Write-Host
"{0,-26} | {1,8} | {2,8}" -f 'default (paths reachable)',    $base_default,    $scr_default | Write-Host
"{0,-26} | {1,8} | {2,8}" -f 'redirected (paths blocked)',   $base_redirected, $scr_redirected | Write-Host
Write-Host ""

$fail = 0
if ($scr_exposed -gt 0) {
    Write-Host "FAIL: $scr_exposed exposed env-var categories survived"
    Get-Content $scrubbedFile | Where-Object { $_ -match ' exposed ' } | Write-Host
    $fail = 1
}
if ($scr_default -gt 0) {
    Write-Host "FAIL: $scr_default config paths still fall back to disk defaults"
    Get-Content $scrubbedFile | Where-Object { $_ -match ' default ' } | Write-Host
    $fail = 1
}
if ($fail -eq 0) {
    Write-Host "PASS: env vars cleaned and config paths redirected"
}
exit $fail
