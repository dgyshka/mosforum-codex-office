# Office installation for Windows x64. Run as the ordinary Windows user.
param([switch]$SkipAuthenticatedPluginForCI)
if ($SkipAuthenticatedPluginForCI -and $env:GITHUB_ACTIONS -ne 'true') {
    throw 'Пропуск авторизации разрешён только на одноразовом тестовом компьютере GitHub.'
}
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$env:PYTHONUTF8 = '1'
$root = $PSScriptRoot
. (Join-Path $root 'windows-office-common.ps1')

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Этот установщик предназначен для Windows.' }
    if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'Эта версия рассчитана на Windows x64. Для ARM или 32-битной Windows обратитесь к Дарье.'
    }
    if ([Environment]::OSVersion.Version.Build -lt 19041) { throw 'Обновите Windows до Windows 10 2004 или новее; рекомендуется Windows 11.' }
    $userRoot = $env:USERPROFILE
    $codexRoot = Join-Path $userRoot '.codex'
    if ($env:CODEX_HOME -and $env:CODEX_HOME.TrimEnd('\','/') -ne $codexRoot) {
        throw 'Обнаружен нестандартный CODEX_HOME. Для него требуется отдельная настройка.'
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'Не найден winget. Откройте Microsoft Store, установите или обновите «Установщик приложений» (App Installer), перезапустите терминал и повторите команду.'
    }
    $codexCommand = Get-Command codex.exe,codex.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $codexCommand) { throw 'Сначала выполните пункт 2: установите Codex и откройте новый терминал.' }
    $codexExe = $codexCommand.Source
    $documents = [Environment]::GetFolderPath('MyDocuments')
    if (-not $documents) { throw 'Не удалось определить папку «Документы» Windows.' }
    foreach ($file in @('windows-packages.json','install-codex-profile.py','configure-office-windows.py','configure-cursor-windows.cjs','office-notify-windows.py','verify-office-windows.py','profile\AGENTS.office.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $file) -PathType Leaf)) { throw "В архиве отсутствует $file. Повторите загрузку установщика." }
    }
    $packages = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'windows-packages.json') | ConvertFrom-Json
    foreach ($name in @('xlsx','docx','pdf','pptx','doc-coauthoring','internal-comms')) {
        if (-not (Test-Path (Join-Path $root "profile\skills\$name\SKILL.md"))) { throw "Не найден навык $name. Повторите загрузку." }
    }
    $policy = Get-ExecutionPolicy -List
    foreach ($scope in @('MachinePolicy','UserPolicy')) {
        $value = ($policy | Where-Object Scope -eq $scope).ExecutionPolicy
        if ($value -and $value -notin @('Undefined','RemoteSigned','Unrestricted','Bypass')) {
            throw 'Политика организации запрещает загрузку неподписанных профилей PowerShell. Обратитесь к администратору; установщик не обходит эту политику.'
        }
    }
    Write-Host "`nПодключить установленный Google Chrome к Codex?"
    Write-Host '1 - Подключить. Будет отдельное окно Chrome; в аккаунты нужно войти самостоятельно.'
    Write-Host '    Содержимое открытых страниц может передаваться Codex для выполнения поручения.'
    Write-Host '2 - Пропустить. Документы и навыки останутся доступны.'
    do { $choice = Read-Host 'Введите 1 или 2 (Enter - пропустить)' } while ($choice -notin @('','1','2'))
    $browserRequested = $choice -eq '1'
    $backup = Join-Path $codexRoot ('backups\windows-system-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    @{
        Path = [Environment]::GetEnvironmentVariable('Path','User')
        NODE_PATH = [Environment]::GetEnvironmentVariable('NODE_PATH','User')
        TESSDATA_PREFIX = [Environment]::GetEnvironmentVariable('TESSDATA_PREFIX','User')
        ExecutionPolicy = (Get-ExecutionPolicy -Scope CurrentUser).ToString()
    } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $backup 'environment-before.json')
    if (Test-Path (Join-Path $codexRoot 'config.toml')) { Copy-Item (Join-Path $codexRoot 'config.toml') (Join-Path $backup 'config.toml') }
    Write-Host "Копия прежних настроек: $backup"
    foreach ($package in $packages.winget) { Ensure-OfficePackage $package.id $package.label }
    $python = $null
    $pythonCandidates = @((Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'), (Join-Path $env:ProgramFiles 'Python312\python.exe'))
    if (Get-Command py.exe -ErrorAction SilentlyContinue) {
        $candidate = & py.exe -3.12 -c 'import sys;print(sys.executable)' 2>$null
        if ($LASTEXITCODE -eq 0) { $pythonCandidates = @($candidate) + $pythonCandidates }
    }
    foreach ($candidate in $pythonCandidates) { if (Test-Path -LiteralPath $candidate) { $python = $candidate; break } }
    if (-not $python) { throw 'Python 3.12 установлен, но не найден. Перезапустите терминал и повторите установку.' }
    $venv = Join-Path $userRoot '.office-python'
    $venvPython = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPython)) { Invoke-Checked $python @('-m','venv',$venv) }
    Add-OfficeUserPath (Join-Path $venv 'Scripts')
    foreach ($package in $packages.winget) {
        if ($package.tool -eq 'python') { continue }
        $exe = Find-OfficeProgram $package.tool
        if (-not $exe) { throw "Не найдена программа $($package.label) после установки." }
        Add-OfficeUserPath (Split-Path -Parent $exe)
    }
    Invoke-Checked $venvPython (@('-m','pip','install','--disable-pip-version-check') + @($packages.python))
    $npm = Find-OfficeProgram 'npm.cmd'
    $node = Find-OfficeProgram 'node.exe'
    if (-not $npm -or -not $node) { throw 'Не найдены Node.js и npm после установки.' }
    Invoke-Checked $npm (@('install','-g','--no-audit','--no-fund') + @($packages.node))
    $nodeRoot = (& $npm root -g | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось определить папку Node-библиотек.' }
    [Environment]::SetEnvironmentVariable('NODE_PATH',$nodeRoot,'User'); $env:NODE_PATH = $nodeRoot
    Add-OfficeUserPath (Split-Path -Parent $codexExe)
    $tesseract = Find-OfficeProgram 'tesseract.exe'
    $tessdata = Install-OfficeOcrData $codexRoot $tesseract
    [Environment]::SetEnvironmentVariable('TESSDATA_PREFIX',$tessdata,'User'); $env:TESSDATA_PREFIX = $tessdata
    Invoke-Checked $venvPython @((Join-Path $root 'install-codex-profile.py'),'--platform','windows','--documents',$documents)
    if ($SkipAuthenticatedPluginForCI) {
        Write-Host 'CI: установка Superpowers не проверяется - требуется личный вход в ChatGPT.'
    } else {
        Invoke-Checked $codexExe @('plugin','add','superpowers@openai-curated-remote','--json')
        $pluginOutput = & $codexExe plugin list --json
        if ($LASTEXITCODE -ne 0) { throw 'Не удалось проверить Superpowers.' }
        $plugins = ($pluginOutput -join "`n") | ConvertFrom-Json
        if (-not ($plugins.installed | Where-Object { $_.name -eq 'superpowers' -and $_.installed -and $_.enabled })) {
            throw 'Superpowers не включён. Настройка не завершена.'
        }
    }
    $chrome = $null
    if ($browserRequested) {
        $candidates = @((Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'), (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'))
        if (${env:ProgramFiles(x86)}) { $candidates += Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe' }
        foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { $chrome = $candidate; break } }
        if ($chrome) {
            $tool = Join-Path $codexRoot 'tools\mosforum-browser'
            $beforeSkip = $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD
            try {
                $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = '1'
                Invoke-Checked $npm @('install','--prefix',$tool,'--no-audit','--no-fund','@playwright/mcp')
            } finally { $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = $beforeSkip }
        } else { Write-Host 'Chrome не найден. Подключение пропущено; новый браузер не скачивается.' }
    }
    $configure = @((Join-Path $root 'configure-office-windows.py'),'--documents',$documents,'--codex',$codexExe)
    if ($chrome) { $configure += @('--chrome',$chrome,'--node',$node) }
    Invoke-Checked $venvPython $configure
    $cursorSettings = Join-Path $env:APPDATA 'Cursor\User\settings.json'
    Invoke-Checked $node @((Join-Path $root 'configure-cursor-windows.cjs'), $cursorSettings, $backup)
    # Local generated PowerShell profiles need RemoteSigned. Never override Group Policy.
    if ((Get-ExecutionPolicy -Scope CurrentUser) -in @('Undefined','Restricted','AllSigned')) {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue
        if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') {
            throw 'Не удалось разрешить загрузку локального профиля PowerShell. Обратитесь к Дарье.'
        }
    }
    Invoke-Checked $venvPython @((Join-Path $root 'verify-office-windows.py'))
    if ($SkipAuthenticatedPluginForCI) {
        Write-Host "`nCI: офисные программы проверены; подключение Superpowers требует отдельной проверки с авторизацией."
    } else {
        Write-Host "`nГотово: офисные программы проверены, шесть навыков и Superpowers подключены."
    }
    Write-Host 'Закройте Cursor полностью и откройте снова. В новом терминале PowerShell введите codex.'
    Write-Host 'При первом запуске Codex может запросить настройку защиты Windows и подтверждение администратора.'
} catch {
    Write-Host "`nУстановка остановлена: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Скопируйте сообщение и напишите Дарье. После исправления можно повторить ту же команду.'
    throw
}
