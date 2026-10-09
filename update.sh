#!/usr/bin/env bash
# ==============================================================================
# Antigravity Mobile Harness - Atualizador (Linux / macOS / WSL / Git Bash)
# Atualiza um projeto onde o harness JA esta instalado, sem tocar no seu codigo.
#
# Uso: curl -sSL <url>/update.sh | bash   OU   ./update.sh [branch]
#
# ATUALIZADO (sobrescrito, com backup previo em .agents.bak-<data>):
#   .agents/  _specs/prd-template.md  _specs/tasks/_template.md
#   install.ps1  install.sh  update.ps1  update.sh
#
# PRESERVADO (nunca tocado):
#   apps/  _specs/prd.md  _specs/features/  _specs/tasks/T*.md
#   _specs/task-board.md  _references/  README.md  .git/  .gitignore (se existir)
# ==============================================================================

set -e

REPO="${REPO:-MailsonSilva/antigravity-harness}"
BRANCH="${1:-main}"

echo "====================================================="
echo "   Atualizador do Antigravity Mobile Harness"
echo "====================================================="

if [ ! -f ".agents/harness.yaml" ]; then
    echo "ERRO: harness nao encontrado aqui. Rode o install.sh primeiro."
    exit 1
fi

command -v curl >/dev/null || { echo "ERRO: curl nao encontrado."; exit 1; }
command -v unzip >/dev/null || { echo "ERRO: unzip nao encontrado."; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
TMPZIP=$(mktemp /tmp/harness-update-XXXXXX.zip)
TMPDIR=$(mktemp -d /tmp/harness-update-XXXXXX)

cleanup() { rm -f "$TMPZIP"; rm -rf "$TMPDIR"; }
trap cleanup EXIT

echo "Baixando https://github.com/$REPO (branch $BRANCH) ..."
curl -sSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$TMPZIP"
unzip -q "$TMPZIP" -d "$TMPDIR"
SRC="$TMPDIR"/$(ls "$TMPDIR")

# 1. Backup do .agents atual
BAK=".agents.bak-$STAMP"
cp -r .agents "$BAK"
echo "Backup criado em: $BAK"

# 2. Sobrescreve SOMENTE arquivos gerenciados pelo harness
rm -rf .agents
cp -r "$SRC/.agents" .agents
for f in "_specs/prd-template.md" "_specs/tasks/_template.md" \
         "install.ps1" "install.sh" "update.ps1" "update.sh"; do
    if [ -f "$SRC/$f" ]; then
        mkdir -p "$(dirname "$f")"
        cp -f "$SRC/$f" "$f"
    fi
done
if [ ! -f ".gitignore" ]; then
    cp -f "$SRC/.gitignore" .gitignore
fi

echo "Harness atualizado a partir de $REPO@$BRANCH."
echo "Preservados: apps/, prd.md, features/, suas tarefas, board e references."
echo "Se algo falhar, restaure com: rm -rf .agents && mv $BAK .agents"
