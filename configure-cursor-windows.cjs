// Enable office terminal signals without replacing the user's JSONC preferences.
const fs = require('fs');
const path = require('path');
const { parse, modify, applyEdits, printParseErrorCode } = require('jsonc-parser');

function configure(settings, backup) {
  if (fs.existsSync(settings) && fs.lstatSync(settings).isSymbolicLink()) {
    throw new Error('Настройки Cursor являются ссылкой; требуется отдельная проверка.');
  }
  const previous = fs.existsSync(settings) ? fs.readFileSync(settings, 'utf8') : '{}\n';
  let updated = previous.replace(/^\uFEFF/, '');
  const errors = [];
  const parsed = parse(updated, errors, { allowTrailingComma: true, allowEmptyContent: true });
  if (errors.length || (parsed !== undefined && (!parsed || Array.isArray(parsed) || typeof parsed !== 'object'))) {
    throw new Error('Не удалось прочитать настройки Cursor: ' + errors.map(e => printParseErrorCode(e.error)).join(', '));
  }
  for (const [key, value] of [
    [['terminal.integrated.enableBell'], true],
    [['accessibility.signals.terminalBell', 'sound'], 'on'],
    [['workbench.panel.opensMaximized'], 'always'],
  ]) {
    updated = applyEdits(updated, modify(updated, key, value, {
      formattingOptions: { insertSpaces: true, tabSize: 2, eol: previous.includes('\r\n') ? '\r\n' : '\n' },
    }));
  }
  if (updated === previous) return;
  fs.mkdirSync(backup, { recursive: true });
  if (fs.existsSync(settings)) fs.copyFileSync(settings, path.join(backup, 'Cursor-settings.json'));
  fs.mkdirSync(path.dirname(settings), { recursive: true });
  fs.writeFileSync(settings, updated, 'utf8');
}

module.exports = { configure };
if (require.main === module) {
  try {
    if (process.argv.length !== 4) throw new Error('Нужны путь настроек Cursor и папка резервной копии.');
    configure(process.argv[2], process.argv[3]);
    console.log('Звук запросов и развёрнутый терминал Cursor настроены.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
