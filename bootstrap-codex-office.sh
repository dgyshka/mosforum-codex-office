#!/usr/bin/env bash
# Public download; no GitHub account or Git installation required.
set -euo pipefail
REPO="dgyshka/mosforum-codex-office"
mkdir -p "$HOME/.codex/installers"
DEST="$(mktemp -d "$HOME/.codex/installers/office-XXXXXXXX")"
printf 'Скачиваю офисный установщик Codex...\n'
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" -o "$DEST/package.tgz"
tar -xzf "$DEST/package.tgz" -C "$DEST" --strip-components=1
if [ ! -f "$DEST/setup-codex-office.sh" ]; then
  echo 'Версия для Codex ещё не опубликована или архив неполный.' >&2
  exit 1
fi
# The download command is piped to bash: reconnect setup input to the terminal
# so Russian choice prompts and Homebrew password input remain interactive.
if [ -t 0 ]; then
  exec bash "$DEST/setup-codex-office.sh"
elif ( : </dev/tty ) 2>/dev/null; then
  exec bash "$DEST/setup-codex-office.sh" </dev/tty
else
  echo "Откройте терминал и выполните: bash \"$DEST/setup-codex-office.sh\"" >&2
  exit 1
fi
