#!/usr/bin/env bash
# Separate macOS office setup. Does not invoke setup.sh or modify ~/.claude.
set -euo pipefail
trap 'printf "\nУстановка остановлена (строка %s). Исправьте ошибку выше и повторите команду.\n" "$LINENO" >&2' ERR
ROOT="$(cd "$(dirname "$0")" && pwd)"
have() { command -v "$1" >/dev/null 2>&1; }
add_profile() { grep -qFx "$1" "$HOME/.zprofile" 2>/dev/null || printf '%s\n' "$1" >> "$HOME/.zprofile"; }

if [ "$(uname -s)" != Darwin ]; then echo 'Этот установщик предназначен для macOS.'; exit 1; fi
if [ -n "${CODEX_HOME:-}" ] && [ "$CODEX_HOME" != "$HOME/.codex" ]; then
  echo 'Обнаружен нестандартный CODEX_HOME. Для него требуется отдельная настройка.'; exit 1
fi
export PATH="$HOME/.local/bin:$PATH"
if ! have codex; then
  echo 'Сначала выполните пункт 2 инструкции: установите Codex и откройте новый терминал.'; exit 1
fi
for file in office-tools.sh install-codex-profile.py configure-office.py office-notify.py install-office-browser.sh profile/AGENTS.office.md; do
  [ -f "$ROOT/$file" ] || { echo "Не найден $file. Распакуйте архив целиком."; exit 1; }
done
BROWSER=0
printf '\nПодключить управление Google Chrome к Codex?\n'
printf '1 - Подключить установленный Chrome. Codex сможет работать с сайтами по вашему поручению.\n'
printf '    Новый браузер не скачивается. Будет отдельное окно Chrome; в аккаунты нужно войти самостоятельно.\n'
printf '    Содержимое открытых страниц может передаваться Codex для выполнения задачи.\n'
printf '2 - Пропустить. Работа с документами останется доступна.\n'
while true; do
  if ! read -r -p 'Введите 1 или 2 (Enter - пропустить): ' CHOICE; then CHOICE=2; fi
  case "$CHOICE" in
    1) BROWSER=1; break;;
    2|'') break;;
    *) echo 'Пожалуйста, введите цифру 1 или 2.';;
  esac
done
for name in xlsx docx pdf pptx doc-coauthoring internal-comms; do
  [ -f "$ROOT/profile/skills/$name/SKILL.md" ] || { echo "В архиве отсутствует навык $name"; exit 1; }
done
# Back up files before Homebrew, office-tools or plugin installation can change them.
mkdir -p "$HOME/.codex/backups"
BACKUP="$(mktemp -d "$HOME/.codex/backups/office-system-XXXXXXXX")"
for file in .zprofile .codex/config.toml; do
  if [ -f "$HOME/$file" ]; then
    mkdir -p "$BACKUP/$(dirname "$file")"
    cp -p "$HOME/$file" "$BACKUP/$file"
  fi
done
echo "Резервная копия настроек: $BACKUP"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo 'Завершите установку инструментов Apple в открывшемся окне, затем повторите эту же команду.'
  exit 1
fi
for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$p" ]; then eval "$("$p" shellenv)"; break; fi
done
if ! have brew; then
  DOWNLOADED_INSTALLER="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$DOWNLOADED_INSTALLER"
  /bin/bash "$DOWNLOADED_INSTALLER"
  rm -f "$DOWNLOADED_INSTALLER"
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$p" ]; then eval "$("$p" shellenv)"; break; fi
  done
fi
have brew || { echo 'Homebrew не установлен.'; exit 1; }
BREW_BIN="$(command -v brew)"
add_profile "eval \"\$(\"$BREW_BIN\" shellenv)\""
brew install git jq node@22 python@3.12
NODE_BIN="$(brew --prefix node@22)/bin"
export PATH="$NODE_BIN:$HOME/.office-python/bin:$PATH"
add_profile "export PATH=\"$NODE_BIN:\$PATH\""
if [ ! -x "$HOME/.office-python/bin/python3" ]; then
  "$(brew --prefix python@3.12)/bin/python3.12" -m venv "$HOME/.office-python"
fi
add_profile 'export PATH="$HOME/.office-python/bin:$PATH"'
if [ ! -d /Applications/Cursor.app ] && [ ! -d "$HOME/Applications/Cursor.app" ]; then
  brew install --cask cursor
fi
bash "$ROOT/office-tools.sh"
"$HOME/.office-python/bin/python3" "$ROOT/install-codex-profile.py"
codex plugin add superpowers@openai-curated-remote --json
codex plugin list --json > "$BACKUP/plugins-after.json"
"$HOME/.office-python/bin/python3" - "$BACKUP/plugins-after.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    data = json.load(stream)
assert any(p.get('name') == 'superpowers' and p.get('installed') and p.get('enabled')
           for p in data.get('installed', [])), 'Superpowers не включён. Настройка не завершена.'
PY
if [ "$BROWSER" = 1 ]; then
  if bash "$ROOT/install-office-browser.sh"; then
    "$HOME/.office-python/bin/python3" "$ROOT/configure-office.py" --browser
  else
    echo 'Подключить Chrome не удалось. Офис настроится без него; повторите установку позже.'
    "$HOME/.office-python/bin/python3" "$ROOT/configure-office.py"
  fi
else
  "$HOME/.office-python/bin/python3" "$ROOT/configure-office.py"
fi
printf '\nГотово: офисные инструменты проверены, шесть навыков и Superpowers подключены.\n'
printf 'Полностью закройте Cursor. Затем откройте в нём Документы/Отчёты/МосФорум.code-workspace.\n'
printf 'При первом открытии разрешите автоматический запуск задачи, как показано в инструкции.\n'
