# Shared Windows installer helpers; no work is done merely by importing this file.
function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Не удалось выполнить $File (код $LASTEXITCODE)." }
}

function Refresh-OfficePath {
    $allPaths = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:Path
    $env:Path = (($allPaths -split ';' | Where-Object { $_ } | Select-Object -Unique) -join ';')
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
    & winget install --id $Id --exact --source winget --architecture x64 --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 3010) { throw 'Нужна перезагрузка Windows. Перезагрузите компьютер и повторите команду установки.' }
    if ($LASTEXITCODE -ne 0) { throw "Не удалось установить $Label. Код: $LASTEXITCODE. Сохраните текст ошибки и напишите Дарье." }
    Refresh-OfficePath
}

function Install-OfficeOcrData {
    param([string]$CodexRoot, [string]$Tesseract)
    $destination = Join-Path $CodexRoot 'tools\tessdata'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $sources = @(
        $env:TESSDATA_PREFIX,
        (Join-Path (Split-Path -Parent $Tesseract) 'tessdata'),
        (Join-Path $env:ProgramFiles 'Tesseract-OCR\tessdata')
    )
    foreach ($source in $sources) {
        if ($source -and (Test-Path -LiteralPath $source -PathType Container) -and $source -ne $destination) {
            Get-ChildItem -LiteralPath $source -Filter '*.traineddata' -File | ForEach-Object {
                $target = Join-Path $destination $_.Name
                if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $_.FullName -Destination $target }
            }
        }
    }
    foreach ($lang in @('eng','osd','rus')) {
        $target = Join-Path $destination "$lang.traineddata"
        if (-not (Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $target).Length -lt 1024) {
            $download = "$target.download-$([guid]::NewGuid().ToString('N'))"
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/$lang.traineddata" -OutFile $download
            if ((Get-Item -LiteralPath $download).Length -lt 1024) { throw "Не удалось загрузить язык OCR: $lang" }
            Move-Item -LiteralPath $download -Destination $target -Force
        }
    }
    return $destination
}
