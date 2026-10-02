# Disposable GitHub Windows runner only. No account login or model requests.
$ErrorActionPreference = 'Stop'
if (-not $env:GITHUB_ACTIONS) { throw 'This integration check is for disposable GitHub runners only.' }
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Install-Module Microsoft.WinGet.Client -Force -Scope CurrentUser -Repository PSGallery
    Repair-WinGetPackageManager -AllUsers
}
. "$PSScriptRoot\..\windows-office-common.ps1"
Invoke-RestMethod https://chatgpt.com/codex/install.ps1 | Invoke-Expression
Refresh-OfficePath
if (-not (Get-Command codex.exe -ErrorAction SilentlyContinue)) { throw 'Official Codex install failed' }
# Install the optional Chrome connector too, if Chrome is on the runner.
function global:Read-Host { param([string]$Prompt) return '1' }
try { & "$PSScriptRoot\..\setup-codex-office.ps1" -SkipAuthenticatedPluginForCI }
finally { Remove-Item Function:\Read-Host }
Invoke-Checked node.exe @("$PSScriptRoot\test_cursor_settings.cjs")
$settings = Get-Content -Raw (Join-Path $env:APPDATA 'Cursor\User\settings.json') | ConvertFrom-Json
if (-not $settings.'terminal.integrated.enableBell' -or $settings.'accessibility.signals.terminalBell'.sound -ne 'on') {
    throw 'Installer did not enable Cursor terminal sound'
}
$profile = & codex.exe --profile mosforum-office mcp list --json
if ($LASTEXITCODE -ne 0) { throw 'Codex could not read the generated office profile' }
Write-Host 'Native installer, document checks and Codex profile completed successfully.'
