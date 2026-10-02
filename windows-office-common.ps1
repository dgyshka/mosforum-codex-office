# Shared Windows installer helpers; no work is done merely by importing this file.
function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Не удалось выполнить $File (код $LASTEXITCODE)." }
}

function Refresh-OfficePath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Add-OfficeUserPath {
    param([string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return }
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $items = @($current -split ';' | Where-Object { $_ })
    if ($items -notcontains $Directory) {
        [Environment]::SetEnvironmentVariable('Path', (($items + $Directory) -join ';'), 'User')
    }
    if (($env:Path -split ';') -notcontains $Directory) { $env:Path = "$Directory;$env:Path" }
}

function Find-OfficeProgram {
    param([string]$Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Links'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'LibreOffice\program'),
        (Join-Path $env:ProgramFiles 'Tesseract-OCR'),
        (Join-Path $env:ProgramFiles 'nodejs'),
        (Join-Path $env:ProgramFiles 'Git\cmd'),
        (Join-Path $env:ProgramFiles 'Pandoc'),
        (Join-Path $env:LOCALAPPDATA 'Pandoc')
    )
    $roots += @(Get-ChildItem -LiteralPath $env:ProgramFiles -Directory -Filter 'qpdf*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            $found = Get-ChildItem -LiteralPath $root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    return $null
}

function Ensure-OfficePackage {
    param([string]$Id, [string]$Label)
    & winget list --id $Id --exact --source winget --accept-source-agreements --disable-interactivity *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "$Label уже установлен."; return }
    Write-Host "Устанавливаю $Label..."
    & winget install --id $Id --exact --source winget --architecture x64 --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 3010) { throw 'Нужна перезагрузка Windows. Перезагрузите компьютер и повторите команду установки.' }
    if ($LASTEXITCODE -ne 0) { throw "Не удалось установить $Label. Код: $LASTEXITCODE. Сохраните текст ошибки и напишите Дарье." }
    Refresh-OfficePath
}
