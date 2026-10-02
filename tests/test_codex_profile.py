import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
NAMES = 'xlsx docx pdf pptx doc-coauthoring internal-comms'.split()


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name) / 'home'
        self.source = pathlib.Path(self.tmp.name) / 'profile'
        self.home.mkdir()
        self.source.mkdir()
        (self.source / 'AGENTS.office.md').write_text('Офисные правила\n')
        for name in NAMES:
            folder = self.source / 'skills' / name
            folder.mkdir(parents=True)
            (folder / 'SKILL.md').write_text(f'---\nname: {name}\ndescription: example\n---\nBody\n')
            (folder / 'helper.py').write_text('# asset\n')

    def run_profile(self):
        return subprocess.run([sys.executable, str(ROOT / 'install-codex-profile.py'),
                               '--home', str(self.home), '--source', str(self.source)],
                              capture_output=True, text=True)

    def test_clean_and_repeat_preserve_files(self):
        codex = self.home / '.codex'
        codex.mkdir()
        (codex / 'AGENTS.md').write_text('Личные правила\n')
        (codex / 'config.toml').write_text('model = "personal"\n')
        claude = self.home / '.claude'
        claude.mkdir()
        (claude / 'CLAUDE.md').write_text('Нельзя менять\n')
        for _ in range(2):
            result = self.run_profile()
            self.assertEqual(result.returncode, 0, result.stderr)
        rules = (codex / 'AGENTS.md').read_text()
        self.assertTrue(rules.startswith('Личные правила\n'))
        self.assertEqual(rules.count('Офисные правила'), 1)
        self.assertEqual((codex / 'config.toml').read_text(), 'model = "personal"\n')
        self.assertEqual((claude / 'CLAUDE.md').read_text(), 'Нельзя менять\n')
        for name in NAMES:
            self.assertTrue((codex / 'skills' / name / 'helper.py').is_file())
        self.assertTrue(list((codex / 'backups').glob('office-*/AGENTS.md')))

    def test_missing_skill_writes_nothing(self):
        (self.source / 'skills' / 'pdf' / 'SKILL.md').unlink()
        self.assertNotEqual(self.run_profile().returncode, 0)
        self.assertFalse((self.home / '.codex').exists())

    def test_existing_skill_is_preserved_in_backup(self):
        old = self.home / '.codex' / 'skills' / 'pdf'
        old.mkdir(parents=True)
        (old / 'SKILL.md').write_text('Мой прежний навык')
        self.assertEqual(self.run_profile().returncode, 0)
        backups = list((self.home / '.codex' / 'backups').glob('office-*/skills/pdf/SKILL.md'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'Мой прежний навык')

    def test_broken_markers_fail_before_changes(self):
        codex = self.home / '.codex'
        codex.mkdir()
        original = '<!-- mosforum-office:start -->\nbroken'
        (codex / 'AGENTS.md').write_text(original)
        self.assertNotEqual(self.run_profile().returncode, 0)
        self.assertEqual((codex / 'AGENTS.md').read_text(), original)
        self.assertFalse((codex / 'skills').exists())


if __name__ == '__main__':
    unittest.main()
