const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parse } = require('jsonc-parser');
const { configure } = require('../configure-cursor-windows.cjs');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'cursor-settings-test-'));
try {
  const settings = path.join(temp, 'Cursor', 'settings.json');
  fs.mkdirSync(path.dirname(settings));
  const before = '{\n// Личная тема\n"workbench.colorTheme": "Light",\n"accessibility.signals.terminalBell": {"announcement":"off", "sound":"off"},\n}\n';
  fs.writeFileSync(settings, before);
  configure(settings, path.join(temp, 'backup1'));
  const once = fs.readFileSync(settings, 'utf8');
  const result = parse(once);
  assert.equal(result['workbench.colorTheme'], 'Light');
  assert.equal(result['terminal.integrated.enableBell'], true);
  assert.equal(result['accessibility.signals.terminalBell'].sound, 'on');
  assert.equal(result['accessibility.signals.terminalBell'].announcement, 'off');
  assert.ok(once.includes('// Личная тема'));
  assert.equal(fs.readFileSync(path.join(temp, 'backup1', 'Cursor-settings.json'), 'utf8'), before);
  configure(settings, path.join(temp, 'backup2'));
  assert.equal(fs.readFileSync(settings, 'utf8'), once);
  fs.writeFileSync(settings, '{broken');
  assert.throws(() => configure(settings, path.join(temp, 'backup3')));
  assert.equal(fs.readFileSync(settings, 'utf8'), '{broken');
  console.log('Cursor settings: comments, theme, backup, repeat and invalid JSON checks passed.');
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
