#!/usr/bin/env python3
"""Generate a separate office launch profile; leave the user's base config intact."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import sys
import tempfile


def configure(home, browser=False):
    root = home / '.codex'
    binary_file = root / 'tools/mosforum-browser/chrome-path.txt'
    if browser and not binary_file.is_file():
        raise ValueError('Сначала настройте подключение Chrome: install-office-browser.sh')
    office = root / 'office'
    rc = Path(os.environ.get('ZDOTDIR') or home) / '.zshrc'
    start, end = '# mosforum-office:start', '# mosforum-office:end'
    previous_rc = rc.read_text() if rc.exists() else ''
    if previous_rc.count(start) != previous_rc.count(end) or previous_rc.count(start) > 1:
        raise ValueError('Повреждён офисный блок в .zshrc; исправьте его перед повторной установкой.')
    if start in previous_rc and previous_rc.index(start) > previous_rc.index(end):
        raise ValueError('Неверный порядок офисных маркеров в .zshrc')
    reports = home / 'Documents' / 'Отчёты'
    profile = root / 'mosforum-office.config.toml'
    workspace = reports / 'МосФорум.code-workspace'
    for p in [root, office, reports, profile, workspace, rc]:
        if p.is_symlink():
            raise ValueError('Символическая ссылка требует отдельной проверки: ' + str(p))
    (root / 'backups').mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='experience-', dir=root / 'backups'))
    for p in [profile, workspace, rc]:
        if p.exists():
            shutil.copy2(p, backup / p.name)
    if office.exists():
        shutil.copytree(office, backup / 'office')
    office.mkdir(exist_ok=True)
    reports.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path(__file__).with_name('office-notify.py'), office / 'notify.py')
    def q(value):
        return json.dumps(str(value), ensure_ascii=False)
    config = '''# Офисный профиль. Используется только при запуске через start.sh.
# Личные модель и тема наследуются из основного config.toml.
sandbox_mode = "workspace-write"
approval_policy = "on-request"
approvals_reviewer = "user"
'''
    config += 'notify = [' + q(sys.executable) + ', ' + q(office / 'notify.py') + ']\n'
    config += '''
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
    if browser:
        tool = root / 'tools' / 'mosforum-browser'
        config += '\n[mcp_servers.mosforum_browser]\ncommand = ' + q(shutil.which('node') or 'node') + '\n'
        config += 'args = ' + json.dumps([str(tool/'node_modules/@playwright/mcp/cli.js'), '--executable-path', binary_file.read_text().strip(), '--user-data-dir', str(tool/'browser-profile'), '--output-dir', str(reports)],ensure_ascii=False) + '\n'
        config += 'startup_timeout_sec = 60\n'
    profile.write_text(config)
    launcher = '#!/bin/bash\nset -euo pipefail\nexport PATH="$HOME/.local/bin:$HOME/.office-python/bin:$PATH"\n'
    launcher += 'cd ' + shlex.quote(str(reports)) + '\n'
    launcher += 'exec codex --profile mosforum-office --cd ' + shlex.quote(str(reports)) + ' "$@"\n'
    (office / 'start.sh').write_text(launcher)
    (office / 'start.sh').chmod(0o755)

    # Bare `codex` and exactly `codex --yolo` select the office. Other arguments
    # keep their normal semantics; no global cd or automatic chat on shell startup.
    shell = 'unalias codex 2>/dev/null\n'
    shell += 'function codex() {\n'
    shell += '  if (( $# == 0 )) || { (( $# == 1 )) && [[ "$1" == --yolo ]]; }; then\n'
    shell += '    (cd ' + shlex.quote(str(reports)) + ' && command codex --profile mosforum-office --cd ' + shlex.quote(str(reports)) + ' "$@")\n'
    shell += '  else\n    command codex "$@"\n  fi\n}\n'
    (office / 'shell.zsh').write_text(shell)
    block = start + '\nsource ' + shlex.quote(str(office / 'shell.zsh')) + '\n' + end
    if start in previous_rc:
        updated_rc = previous_rc[:previous_rc.index(start)] + block + previous_rc[previous_rc.index(end)+len(end):]
    else:
        updated_rc = previous_rc + ('\n' if previous_rc else '') + block + '\n'
    rc.parent.mkdir(parents=True, exist_ok=True)
    rc.write_text(updated_rc)

    settings = {
        'workbench.panel.opensMaximized': 'always',
        'workbench.startupEditor': 'none',
        'terminal.integrated.enableBell': True,
        'accessibility.signals.terminalBell': {'sound':'on'},
        'terminal.integrated.defaultProfile.osx': 'Офис Codex',
        'terminal.integrated.profiles.osx': {'Офис Codex': {'path':'/bin/zsh','args':['-l','-c','exec bash '+shlex.quote(str(office/'start.sh'))]}},
    }
    # Workspace settings avoid changing the layout or theme in other projects.
    document = {'folders':[{'path':'.','name':'Отчёты'}], 'settings':settings,
        'tasks':{'version':'2.0.0','tasks':[{
            'label':'Открыть Codex для документов', 'type':'process',
            'command':'/bin/zsh', 'args':['-l','-c','exec bash '+shlex.quote(str(office/'start.sh'))],
            'problemMatcher':[], 'runOptions':{'runOn':'folderOpen'},
            'presentation':{'reveal':'always','focus':True,'panel':'dedicated','echo':False}
        }]}}
    workspace.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    print('Настроено рабочее место: '+str(workspace))
    print('Резервная копия: '+str(backup))

if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--home',type=Path,default=Path.home())
    p.add_argument('--browser',action='store_true')
    args=p.parse_args()
    configure(args.home,args.browser)
