#!/usr/bin/env python3
"""Install the office profile without reading or modifying Claude's configuration."""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import tempfile

NAMES = 'xlsx docx pdf pptx doc-coauthoring internal-comms'.split()
START = '<!-- mosforum-office:start -->'
END = '<!-- mosforum-office:end -->'
NOTE = '''
## Codex compatibility

This skill runs in Codex on the user's Mac. References to Claude describe the
original authoring environment; use available Codex tools and connectors.
Resolve helper scripts relative to this skill directory. Use local files instead
of Claude artifacts or sandbox-only paths. Do not claim unavailable tools,
connectors or independent reviewers exist. Do not request Claude credentials.
For reader testing use an available authorized reviewer, or ask the user to open
a fresh Codex conversation. Never describe self-review as independent review.
Follow current user instructions and AGENTS.md. Save outputs as new local files.

'''


def install(home, source):
    rules = (source / 'AGENTS.office.md').read_text()
    for name in NAMES:
        body = (source / 'skills' / name / 'SKILL.md').read_text()
        if not body.startswith('---\n') or '\n---\n' not in body[4:]:
            raise ValueError('Invalid skill metadata: ' + name)
    root = home / '.codex'
    agents = root / 'AGENTS.md'
    # Refuse symlink targets instead of accidentally editing shared Claude files.
    for target in [root, agents, root / 'skills'] + [root / 'skills' / n for n in NAMES]:
        if target.is_symlink():
            raise ValueError('Symlink target requires manual review: ' + str(target))
    previous = agents.read_text() if agents.exists() else ''
    if previous.count(START) != previous.count(END) or previous.count(START) > 1:
        raise ValueError('Incomplete or repeated office markers in AGENTS.md')
    block = START + '\n' + rules.rstrip() + '\n' + END
    if START in previous:
        begin, finish = previous.index(START), previous.index(END)
        if begin > finish:
            raise ValueError('Office markers are reversed')
        updated = previous[:begin] + block + previous[finish + len(END):]
    else:
        updated = previous + ('\n\n' if previous else '') + block + '\n'
    root.mkdir(parents=True, exist_ok=True)
    backup_root = root / 'backups'
    backup_root.mkdir(exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='office-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-'), dir=backup_root))
    if agents.exists():
        shutil.copy2(agents, backup / 'AGENTS.md')
    (root / 'skills').mkdir(exist_ok=True)
    # Copy all assets before swapping any skill directories.
    with tempfile.TemporaryDirectory(prefix='office-stage-', dir=root) as staging:
        stage = Path(staging)
        for name in NAMES:
            shutil.copytree(source / 'skills' / name, stage / name)
            skill = stage / name / 'SKILL.md'
            body = skill.read_text()
            split = body.index('\n---\n', 4) + len('\n---\n')
            skill.write_text(body[:split] + NOTE + body[split:])
        for name in NAMES:
            target = root / 'skills' / name
            if target.exists():
                (backup / 'skills').mkdir(exist_ok=True)
                shutil.move(str(target), str(backup / 'skills' / name))
            shutil.move(str(stage / name), str(target))
        temporary = stage / 'AGENTS.md'
        temporary.write_text(updated)
        os.replace(temporary, agents)
    (home / 'Documents' / 'Отчёты').mkdir(parents=True, exist_ok=True)
    print('Шесть навыков и офисные правила установлены. Копия прежних файлов: ' + str(backup))
    if (root / 'AGENTS.override.md').exists():
        print('ВНИМАНИЕ: AGENTS.override.md имеет приоритет. Офисные правила из AGENTS.md могут не загружаться.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parent / 'profile')
    args = parser.parse_args()
    install(args.home, args.source)
