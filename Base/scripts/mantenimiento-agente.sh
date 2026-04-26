#!/usr/bin/env bash
# Agente de Mantenimiento Proactivo
# Usage: mantenimiento-agente.sh

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
echo "[INFO] Iniciando mantenimiento..."

# 1. Limpiar temporales antiguos
find /tmp -name "ollama.log.*" -mtime +7 -delete 2>/dev/null || true
find /tmp -name "auto-agente.log.*" -mtime +7 -delete 2>/dev/null || true

# 2. Gestionar tamaño de índice RAG
INDEX_FILE="$AI_ROOT/.rag/index.json"
if [ -f "$INDEX_FILE" ]; then
    TAMANO=$(du -k "$INDEX_FILE" | cut -f1)
    if [ "$TAMANO" -gt 5000 ]; then
        echo "[INFO] Índice RAG grande (${TAMANO}KB), limpiando..."
        python3 /home/mash/Opencode/Base/python/indexador.py clear
        python3 /home/mash/Opencode/Base/python/indexador.py index
    fi
fi

# 3. Comprimir logs antiguos
LOG_DIR="$AI_ROOT/logs"
mkdir -p "$LOG_DIR"
find "$AI_ROOT" -name "*.log" -mtime +30 -exec gzip {} \; 2>/dev/null || true

echo "[OK] Mantenimiento completado."