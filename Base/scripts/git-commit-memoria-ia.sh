#!/usr/bin/env bash
set -euo pipefail

# Git auto-commit para AI-Memory
# Usage: git-commit-memoria-ia.sh [mensaje]

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
DATE_FMT=$(date '+%Y-%m-%d %H:%M')

# Mensaje por defecto
MENSAJE="${1:-Actualización de memoria} - $DATE_FMT"

# Verificar si es un repositorio git
if [ ! -d "$AI_ROOT/.git" ]; then
    echo "Inicializando repositorio Git..."
    cd "$AI_ROOT"
    git init
    git config user.name "IA Assistant"
    git config user.email "ia@local"
    echo "[OK] Repositorio inicializado"
fi

# Agregar cambios
cd "$AI_ROOT"
git add -A

# Verificar si hay cambios
if git diff --staged --quiet; then
    echo "[INFO] No hay cambios nuevos para commit"
    exit 0
fi

# Commit
git commit -m "$MENSAJE"

echo "[OK] Commiteado: $MENSAJE"
echo "     Fecha: $DATE_FMT"