import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

class WindowsOfficeTests(unittest.TestCase):
    def test_profiles_preserve_personal_settings_and_chrome_choice(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / "User O'Brien"
            docs = home / 'OneDrive' / 'Документы'
            docs.mkdir(parents=True)
            for name in ['WindowsPowerShell', 'PowerShell']:
                folder = docs / name
                folder.mkdir()
                (folder / 'profile.ps1').write_text('# Личные настройки\n', encoding='utf-8-sig')
            (home / '.codex').mkdir()
            config = home / '.codex/config.toml'
            config.write_text('model = "personal"\n', encoding='utf-8')
            for _ in range(2):
                result = subprocess.run([sys.executable, str(ROOT/'configure-office-windows.py'),
                    '--home', str(home), '--documents', str(docs), '--codex', 'C:\\Tools\\codex.exe'], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(config.read_text(), 'model = "personal"\n')
            for name in ['WindowsPowerShell', 'PowerShell']:
                body = (docs/name/'profile.ps1').read_text(encoding='utf-8-sig')
                self.assertTrue(body.startswith('# Личные настройки\n'))
                self.assertEqual(body.count('# mosforum-office:start'), 1)
            config_body = (home/'.codex/mosforum-office.config.toml').read_text(encoding='utf-8')
            self.assertIn('[windows]', config_body)
            self.assertIn('sandbox = "elevated"', config_body)
            self.assertNotIn('mcp_servers', config_body)
            shell = (home/'.codex/office/shell.ps1').read_text(encoding='utf-8-sig')
            self.assertIn("--yolo", shell)
            self.assertIn("O''Brien", shell)
            self.assertTrue((docs/'Отчёты').is_dir())
            self.assertTrue(list((home/'.codex/backups').glob('windows-*/WindowsPowerShell/profile.ps1')))

    def test_broken_profile_stops_before_modification(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            docs = home/'Documents'
            (docs/'PowerShell').mkdir(parents=True)
            profile = docs/'PowerShell/profile.ps1'
            content = '# mosforum-office:start\nbroken'
            profile.write_text(content)
            result = subprocess.run([sys.executable,str(ROOT/'configure-office-windows.py'),
                '--home', temp, '--documents', str(docs),'--codex','codex.exe'],capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(profile.read_text(),content)
            self.assertFalse((home/'.codex').exists())

    def test_windows_skills_keep_assets_and_no_mac_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            result = subprocess.run([sys.executable,str(ROOT/'install-codex-profile.py'),
                '--home',temp,'--platform','windows'],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            root = Path(temp)/'.codex'
            rules=(root/'AGENTS.md').read_text(encoding='utf-8')
            self.assertNotIn('этом Mac',rules)
            self.assertIn('Scripts/python.exe',rules)
            names='xlsx docx pdf pptx doc-coauthoring internal-comms'.split()
            for name in names:
                body=(root/'skills'/name/'SKILL.md').read_text(encoding='utf-8')
                self.assertNotIn("user's Mac",body)
                self.assertEqual(len(list((root/'skills'/name).rglob('*'))),len(list((ROOT/'profile/skills'/name).rglob('*'))))

    def test_soffice_shim_is_linux_only(self):
        for name in ['docx','pptx','xlsx']:
            path=ROOT/'profile/skills'/name/'scripts/office/soffice.py'
            spec=importlib.util.spec_from_file_location('soffice_'+name,path)
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            with patch.object(module.sys,'platform','win32'), patch.object(module.socket,'socket',side_effect=AssertionError('must not probe Unix sockets on Windows')):
                self.assertFalse(module._needs_shim())

if __name__ == '__main__': unittest.main()
