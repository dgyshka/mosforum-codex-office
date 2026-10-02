#!/usr/bin/env python3
"""Windows office profile, PowerShell entry points and portable file associations."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile

START, END = '# mosforum-office:start', '# mosforum-office:end'


def ps_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def merge_block(previous, block):
    if previous.count(START) != previous.count(END) or previous.count(START) > 1:
        raise ValueError('Повреждён офисный блок в профиле PowerShell')
    if START in previous:
        begin, finish = previous.index(START), previous.index(END)
        if begin > finish:
            raise ValueError('Неверный порядок офисных маркеров в профиле PowerShell')
        return previous[:begin] + block + previous[finish + len(END):]
    return previous + ('\n' if previous else '') + block + '\n'


def read_profile(path):
    data = path.read_bytes()
    if data.startswith((b'\xff\xfe', b'\xfe\xff')):
        return data.decode('utf-16')
    try:
        return data.decode('utf-8-sig')
    except UnicodeDecodeError:
        raise ValueError('Профиль PowerShell должен быть в UTF-8 или UTF-16: ' + str(path))


def configure(home, documents, codex, chrome=None, node=None):
    root = home / '.codex'
    office = root / 'office'
    reports = documents / 'Отчёты'
    profile = root / 'mosforum-office.config.toml'
    workspace = reports / 'МосФорум.code-workspace'
    profiles = [documents / p / 'profile.ps1' for p in ['WindowsPowerShell', 'PowerShell']]
    for p in [root, office, reports, profile, workspace] + profiles:
        if p.is_symlink():
            raise ValueError('Символическая ссылка требует отдельной проверки: ' + str(p))
    block = START + '\n. ' + ps_quote(office / 'shell.ps1') + '\n' + END
    # Validate both existing PowerShell profiles before changing anything.
    updates = {p: merge_block(read_profile(p) if p.exists() else '', block) for p in profiles}
    (root / 'backups').mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='windows-', dir=root / 'backups'))
    for p in [profile, workspace] + profiles:
        if p.exists():
            target = backup / p.parent.name / p.name if p in profiles else backup / p.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
    if office.exists():
        shutil.copytree(office, backup / 'office')
    office.mkdir(exist_ok=True)
    reports.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path(__file__).with_name('office-notify-windows.py'), office / 'notify-windows.py')
    q = lambda value: json.dumps(str(value), ensure_ascii=False)
    content = '# Офисный профиль Windows; модель и тема наследуются из личных настроек.\n'
    content += 'sandbox_mode = "workspace-write"\napproval_policy = "on-request"\napprovals_reviewer = "user"\n'
    content += 'notify = [' + q(sys.executable) + ', ' + q(office/'notify-windows.py') + ']\n'
    content += '''
[windows]
sandbox = "elevated"

[sandbox_workspace_write]
writable_roots = []
network_access = false

[tui]
status_line = ["model-with-reasoning", "current-dir", "context-remaining"]
alternate_screen = "always"
notifications = ["approval-requested"]
notification_method = "bel"
notification_condition = "always"
'''
    if chrome:
        if not node:
            raise ValueError('Для подключения Chrome нужен путь к node.exe')
        tool = root / 'tools/mosforum-browser'
        content += '\n[mcp_servers.mosforum_browser]\ncommand = ' + q(node) + '\n'
        content += 'args = ' + json.dumps([str(tool/'node_modules/@playwright/mcp/cli.js'),
            '--executable-path', chrome, '--user-data-dir', str(tool/'browser-profile'),
            '--output-dir', str(reports)], ensure_ascii=False) + '\nstartup_timeout_sec = 60\n'
    profile.write_text(content, encoding='utf-8')
    shell = "Remove-Item Alias:codex -ErrorAction SilentlyContinue\nfunction global:codex {\n"
    shell += '    $officeArgs = @($args)\n'
    shell += "    if ($officeArgs.Count -eq 0 -or ($officeArgs.Count -eq 1 -and $officeArgs[0] -eq '--yolo')) {\n"
    shell += '        Push-Location -LiteralPath ' + ps_quote(reports) + '\n'
    shell += '        try { & ' + ps_quote(codex) + ' --profile mosforum-office --cd ' + ps_quote(reports) + ' @officeArgs }\n'
    shell += '        finally { Pop-Location }\n'
    shell += '    } else { & ' + ps_quote(codex) + ' @officeArgs }\n}\n'
    (office/'shell.ps1').write_text(shell, encoding='utf-8-sig')
    launcher = 'Push-Location -LiteralPath ' + ps_quote(reports) + '\n'
    launcher += 'try { & ' + ps_quote(codex) + ' --profile mosforum-office --cd ' + ps_quote(reports) + ' @args }\nfinally { Pop-Location }\n'
    (office/'start.ps1').write_text(launcher, encoding='utf-8-sig')
    for path, updated in updates.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(updated, encoding='utf-8-sig')
    settings = {'workbench.panel.opensMaximized':'always', 'workbench.startupEditor':'none',
        'terminal.integrated.enableBell':True, 'accessibility.signals.terminalBell':{'sound':'on'},
        'terminal.integrated.defaultProfile.windows':'Офис PowerShell',
        'terminal.integrated.profiles.windows':{'Офис PowerShell':{'path':'powershell.exe','args':['-NoLogo']}}}
    workspace.write_text(json.dumps({'folders':[{'path':'.','name':'Отчёты'}], 'settings':settings},ensure_ascii=False,indent=2),encoding='utf-8')
    print('Офисный профиль Windows настроен. Резервная копия: ' + str(backup))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--documents', type=Path, required=True)
    parser.add_argument('--codex', required=True)
    parser.add_argument('--chrome')
    parser.add_argument('--node')
    args = parser.parse_args()
    configure(args.home, args.documents, args.codex, args.chrome, args.node)
