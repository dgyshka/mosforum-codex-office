#!/bin/bash
# Use the installed Google Chrome. Never download Chromium or copy personal cookies.
set -euo pipefail
CHROME=''
for candidate in '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
  if [ -x "$candidate" ]; then CHROME="$candidate"; break; fi
done
if [ -z "$CHROME" ]; then
  echo 'Google Chrome не найден. Подключение пропущено. Установите Chrome с google.com/chrome и повторите настройку, если он нужен.' >&2
  exit 1
fi
TOOL="$HOME/.codex/tools/mosforum-browser"
mkdir -p "$TOOL"
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --prefix "$TOOL" --no-audit --no-fund @playwright/mcp
printf '%s\n' "$CHROME" > "$TOOL/chrome-path.txt"
printf 'Подключение к Google Chrome подготовлено. Новый браузер не скачивался.\n'
printf 'Codex будет открывать отдельное окно Chrome со своим профилем. В сайты войдите самостоятельно.\n'
