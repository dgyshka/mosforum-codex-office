#!/usr/bin/env bash
# =============================================================================
# Офисные инструменты для Claude Code (macOS): Excel, Word, PDF, презентации
# Запуск:  bash office-tools.sh
# Ставит то, на что опираются скиллы xlsx / docx / pdf / pptx:
#   LibreOffice, pandoc, poppler, qpdf, tesseract (с русским языком),
#   Python-библиотеки и Node-библиотеки для сборки документов.
# Настройки Claude Code не трогает. Можно запускать повторно.
# Вызывается из setup.sh --office, но работает и сам по себе.
# =============================================================================
set -uo pipefail

PROBLEMS=()
say()  { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; PROBLEMS+=("$*"); }
have() { command -v "$1" >/dev/null 2>&1; }
add_profile() { grep -qF "$1" "$HOME/.zprofile" 2>/dev/null || echo "$1" >> "$HOME/.zprofile"; }

if [ "$(uname -s)" != "Darwin" ]; then echo "Это скрипт для Mac."; exit 1; fi
for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$p" ] && eval "$("$p" shellenv)" && break
done
if ! have brew; then echo "Нужен Homebrew. Сначала запусти setup.sh --office"; exit 1; fi

say "Офис 1/4. Программы: LibreOffice, pandoc, poppler, qpdf, tesseract"
if [ -d "/Applications/LibreOffice.app" ]; then ok "LibreOffice уже стоит"
else
  echo "  LibreOffice - большая загрузка (~1 ГБ), может занять 5-15 минут."
  brew install --quiet --cask libreoffice >/dev/null 2>&1 && ok "LibreOffice поставлен" || warn "LibreOffice не поставился"
fi
# Claude ищет LibreOffice по команде soffice - кладём её в PATH
SOFFICE_BIN="/Applications/LibreOffice.app/Contents/MacOS"
[ -d "$SOFFICE_BIN" ] && export PATH="$PATH:$SOFFICE_BIN" && add_profile "export PATH=\"\$PATH:$SOFFICE_BIN\""
for f in pandoc poppler qpdf tesseract tesseract-lang; do
  if brew list --formula "$f" >/dev/null 2>&1; then ok "$f уже стоит"
  else brew install --quiet "$f" >/dev/null 2>&1 && ok "$f поставлен" || warn "$f не поставился"
  fi
done

say "Офис 2/4. Python для таблиц, документов и PDF"
PY_PKGS=(openpyxl pandas python-docx python-pptx pypdf pdfplumber pypdfium2 reportlab
         pdf2image pytesseract Pillow numpy defusedxml lxml "markitdown[all]")
# Годится системный python3, если он 3.10+ и позволяет ставить пакеты.
# Иначе (чистый Mac) - отдельное окружение на Python из Homebrew.
py_ok() {
  "$1" -c 'import sys,sysconfig,os
sys.exit(0 if sys.version_info>=(3,10) and not os.path.exists(os.path.join(sysconfig.get_path("stdlib"),"EXTERNALLY-MANAGED")) else 1)' 2>/dev/null
}
VENV="$HOME/.office-python"
if [ -x "$VENV/bin/python3" ]; then
  PY="$VENV/bin/python3"; export PATH="$VENV/bin:$PATH"; ok "беру окружение $VENV"
elif have python3 && py_ok python3; then
  PY="$(command -v python3)"; ok "беру имеющийся $($PY --version)"
else
  brew install --quiet python@3.12 >/dev/null 2>&1 || warn "Python 3.12 не поставился"
  "$(brew --prefix)/opt/python@3.12/bin/python3.12" -m venv "$VENV" && ok "создано окружение $VENV" || warn "окружение Python не создалось"
  PY="$VENV/bin/python3"; export PATH="$VENV/bin:$PATH"
  add_profile "export PATH=\"$VENV/bin:\$PATH\""
fi
if "$PY" -m pip install --quiet --disable-pip-version-check "${PY_PKGS[@]}" >/dev/null 2>&1 \
   || "$PY" -m pip install --quiet --disable-pip-version-check --user "${PY_PKGS[@]}" >/dev/null 2>&1; then
  ok "библиотеки Python поставлены"
else warn "библиотеки Python поставились не все"
fi
# markitdown с --user может лечь вне PATH - добавляем папку со скриптами
USER_BIN="$("$PY" -c 'import site,os;print(os.path.join(site.getuserbase(),"bin"))' 2>/dev/null)"
if [ -n "$USER_BIN" ] && [ -x "$USER_BIN/markitdown" ] && ! have markitdown; then
  export PATH="$PATH:$USER_BIN"; add_profile "export PATH=\"\$PATH:$USER_BIN\""
fi

say "Офис 3/4. Node-библиотеки для Word и PowerPoint"
if have npm; then
  npm install -g --silent docx pptxgenjs react-icons react react-dom sharp >/dev/null 2>&1 \
    && ok "docx, pptxgenjs и помощники поставлены" || warn "Node-библиотеки поставились не все"
  # Без этого require('docx') не видит глобально поставленные библиотеки
  NODE_ROOT="$(npm root -g)"; export NODE_PATH="$NODE_ROOT"
  add_profile "export NODE_PATH=\"$NODE_ROOT\""
else warn "нет Node.js - Word/PowerPoint с нуля собираться не будут"
fi

say "Офис 4/4. Проверка: каждый инструмент делает настоящую работу"
T="$(mktemp -d)"
"$PY" - "$T" >/dev/null 2>&1 <<'PYEOF' && ok "Python: Excel, Word и PDF создаются и читаются" || warn "Python-библиотеки не прошли проверку"
import sys, os, openpyxl, pandas, docx, pptx, pypdf, pdfplumber, pypdfium2, defusedxml, lxml, pytesseract, pdf2image
from reportlab.pdfgen import canvas
t = sys.argv[1]
wb = openpyxl.Workbook(); wb.active["A1"] = 2; wb.active["A2"] = "=A1*21"; wb.save(f"{t}/check.xlsx")
d = docx.Document(); d.add_paragraph("Проверка"); d.save(f"{t}/check.docx")
c = canvas.Canvas(f"{t}/check.pdf"); c.drawString(100, 750, "check 42"); c.save()
assert "42" in pypdf.PdfReader(f"{t}/check.pdf").pages[0].extract_text()
assert pandas.read_excel(f"{t}/check.xlsx", header=None).iloc[0, 0] == 2
PYEOF
# Отдельная папка: иначе check.pdf от Python выдал бы себя за результат LibreOffice
mkdir -p "$T/lo"
if have soffice && soffice --headless --convert-to pdf --outdir "$T/lo" "$T/check.docx" >/dev/null 2>&1 && [ -s "$T/lo/check.pdf" ]; then
  ok "LibreOffice: Word превращается в PDF"
else warn "LibreOffice не отвечает на команду soffice"
fi
have pandoc && pandoc "$T/check.docx" -t plain 2>/dev/null | grep -q "Проверка" && ok "pandoc читает Word" || warn "pandoc не читает Word"
have pdftoppm && pdftoppm -png -r 30 -f 1 -l 1 "$T/check.pdf" "$T/page" 2>/dev/null && ls "$T"/page*.png >/dev/null 2>&1 \
  && ok "poppler: страница PDF превращается в картинку" || warn "poppler не работает"
have qpdf && qpdf --check "$T/check.pdf" >/dev/null 2>&1 && ok "qpdf проверяет PDF" || warn "qpdf не работает"
have tesseract && tesseract --list-langs 2>/dev/null | grep -qx rus && ok "tesseract распознаёт русский" || warn "tesseract без русского языка"
have markitdown && markitdown "$T/check.xlsx" 2>/dev/null | grep -q "Sheet" && ok "markitdown читает Excel" || warn "markitdown не работает"
if have node; then
  (cd "$T" && node -e 'require("docx"); require("pptxgenjs")' >/dev/null 2>&1) \
    && ok "Node: docx и pptxgenjs подключаются" || warn "Node не видит docx/pptxgenjs"
fi
rm -rf "$T"

printf "\n"
if [ ${#PROBLEMS[@]} -eq 0 ]; then printf "\033[1;32mОфисные инструменты готовы.\033[0m\n"
else
  printf "\033[1;33mОфисные инструменты: есть замечания\033[0m\n"
  for p in "${PROBLEMS[@]}"; do echo "  - $p"; done
  exit 1
fi
