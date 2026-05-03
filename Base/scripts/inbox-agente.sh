#!/usr/bin/env bash
# Inbox Agente — Clasifica y mueve archivos nuevos
# Usage: inbox-agente.sh [process]

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

INBOX_DIR="/home/mash/Opencode/Obsidian/AI-Memory/Inbox"
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"

echo "[INFO] Procesando Inbox..."

for archivo in "$INBOX_DIR"/*; do
    [ -f "$archivo" ] || continue
    
    CONTENIDO=$(cat "$archivo" | head -n 50)
    
    PROMPT="Eres un clasificador inteligente. Analiza este contenido:
    $CONTENIDO
    
    Responde SOLO con una de estas categorías: 'Proyectos', 'Conocimiento', 'Sistema', o 'Nota-Rapida'."
    
    CATEGORIA=$(curl -s http://127.0.0.1:11434/api/generate \
        -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" | jq -r '.response' 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]' || echo "nota-rapida")
    
    # Mover archivo
    DESTINO="$AI_ROOT/$CATEGORIA/$(basename "$archivo")"
    mkdir -p "$AI_ROOT/$CATEGORIA"
    mv "$archivo" "$DESTINO"
    
    /home/mash/Opencode/Base/scripts/hablar.sh "He clasificado el archivo $(basename "$archivo") en la carpeta $CATEGORIA."
done

echo "[OK] Inbox procesado."