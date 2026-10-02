# Офисное рабочее место с Codex

Установка для macOS: Cursor, Codex, инструменты для Excel, Word, PDF и презентаций, шесть офисных навыков и Superpowers.

Пошаговая инструкция: [открыть в браузере](https://dgyshka.github.io/mosforum-codex-office/). Запасной вариант: [HTML-файл](docs/index.html).

После установки Codex:

```bash
curl -fsSL https://raw.githubusercontent.com/dgyshka/mosforum-codex-office/main/bootstrap-codex-office.sh | bash
```

Установщик предлагает подключить уже установленный Google Chrome. При отказе работа с документами остаётся доступна. Chromium не скачивается. Для Chrome используется отдельный профиль, личные пароли и cookies не копируются.

После установки и открытия нового терминала zsh команды `codex` и `codex --yolo` запускают офисный профиль в «Отчётах». При `--yolo` папка и офисные настройки сохраняются, но подтверждения команд и песочница отключаются. Другие команды с аргументами, включая `codex login`, сохраняют обычное поведение. Настройка добавляется отдельным блоком в `.zshrc`; прежний файл сохраняется в резервной копии.

Запасной офисный запуск: `bash "$HOME/.codex/office/start.sh"`. Рабочее место Cursor: `~/Documents/Отчёты/МосФорум.code-workspace`.

Подготовлено на основе [офисной установки МосФорум](https://github.com/dimazaharov72-beep/mosforum-hackathon-start). Исходные настройки Claude не изменяются. У навыков сохранены их исходные лицензии; этот репозиторий не меняет условия лицензирования сторонних материалов.

Проверены тесты сохранности профиля и повторной установки, синтаксис shell-скриптов и чтение профиля Codex. Полная установка на чистом Mac пока не проверена.

## Проверки для сопровождающего

```bash
python3 -m unittest discover -s tests -v
bash -n bootstrap-codex-office.sh setup-codex-office.sh install-office-browser.sh
```
