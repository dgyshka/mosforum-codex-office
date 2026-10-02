import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ExperienceTests(unittest.TestCase):
    def test_installs_scoped_launcher_and_preserves_global_config(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            (home / '.codex').mkdir()
            config = home / '.codex/config.toml'
            config.write_text('model = "personal"\n')
            for _ in range(2):
                p = subprocess.run(['python3', str(ROOT/'configure-office.py'), '--home', t], capture_output=True, text=True)
                self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(config.read_text(), 'model = "personal"\n')
            profile = (home/'.codex/mosforum-office.config.toml').read_text()
            self.assertIn('sandbox_mode = "workspace-write"', profile)
            self.assertIn('approval_policy = "on-request"', profile)
            self.assertIn('current-dir', profile)
            self.assertNotIn('mcp_servers', profile)
            workspace = json.loads((home/'Documents/Отчёты/МосФорум.code-workspace').read_text())
            self.assertEqual(workspace['settings']['workbench.panel.opensMaximized'], 'always')
            self.assertTrue(list((home/'.codex/backups').glob('experience-*/mosforum-office.config.toml')))
            subprocess.run(['bash','-n',str(home/'.codex/office/start.sh')],check=True)

    def test_notify_only_expected_event(self):
        spec=importlib.util.spec_from_file_location('notify',ROOT/'office-notify.py')
        module=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertIsNone(module.sound_for({'type':'unknown'}))
        self.assertEqual(module.sound_for({'type':'agent-turn-complete'}), '/System/Library/Sounds/Glass.aiff')

    def test_declined_browser_stays_disabled_on_repeat(self):
        with tempfile.TemporaryDirectory() as t:
            binary = Path(t)/'.codex/tools/mosforum-browser/chrome-path.txt'
            binary.parent.mkdir(parents=True)
            binary.write_text('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
            p = subprocess.run(['python3',str(ROOT/'configure-office.py'),'--home',t,'--browser'],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
            content = (Path(t)/'.codex/mosforum-office.config.toml').read_text()
            self.assertIn('Google Chrome', content)
            self.assertNotIn('chromium', content)
            p = subprocess.run(['python3',str(ROOT/'configure-office.py'),'--home',t],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
            self.assertNotIn('mcp_servers', (Path(t)/'.codex/mosforum-office.config.toml').read_text())

if __name__=='__main__': unittest.main()
