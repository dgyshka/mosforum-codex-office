# Windows PowerShell 5.1 or PowerShell 7. Public download; GitHub login not required.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = 'dgyshka/mosforum-codex-office'
$destination = Join-Path $env:USERPROFILE ('.codex\installers\office-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Write-Host 'Скачиваю офисный установщик Codex для Windows...'
$archive = Join-Path $destination 'package.zip'
Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$repo/zip/refs/heads/main" -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $destination
$setup = Join-Path $destination 'mosforum-codex-office-main\setup-codex-office.ps1'
if (-not (Test-Path -LiteralPath $setup)) { throw 'Архив неполный: установщик Windows не найден.' }
& $setup
