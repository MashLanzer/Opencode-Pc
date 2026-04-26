#!/usr/bin/env bash
# Auto-Categorizador — Categoriza notas automáticamente
# Usage: categorizar-nota.sh "nota" [contenido]

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"

# Asegurar Ollama
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

NOTA="${1:-}"
CONTENIDO="${2:-}"

if [ -z "$NOTA" ] || [ -z "$CONTENIDO" ]; then
    echo "Usage: categorizar-nota.sh \"nota.md\" \"contenido...\""
    exit 1
fi

PROMPT="Categoriza esta nota en UNA palabra: sistema, proyecto, conocimiento, error, tarea, meeting, o otro.

Contenido: $CONTENIDO

Responde SOLO con la categoría (ej: proyecto)"

CATEGORIA=$(echo "$PROMPT" | timeout 60 /home/mash/.local/bin/ollama run "$MODEL" 2>/dev/null | head -1 | tr -d ' .' | tr '[:upper:]' '[:lower:]')

# Mapear a carpeta
case "$CATEGORIA" in
    sistema|error|configuracion) CARPETA="Sistema" ;;
    proyecto|vexa|dnd) CARPETA="Proyectos" ;;
    conocimiento|codigo|snippet) CARPETA="Conocimiento" ;;
    tarea) CARPETA="." ;;
    meeting|reunion) CARPETA="Proyectos" ;;
    *) CARPETA="Conocimiento" ;;
esac

# Mover archivo si existe
ORIGEN="$AI_ROOT/$NOTA"
if [ -f "$ORIGEN" ]; then
    DESTINO="$AI_ROOT/$CARPETA/$NOTA"
    mv "$ORIGEN" "$DESTINO"
    echo "[OK] Movido a $CARPETA/"
else
    # Crear nuevo archivo
    DESTINO="$AI_ROOT/$CARPETA/$NOTA"
    echo "# $NOTA" > "$DESTINO"
    echo "" >> "$DESTINO"
    echo "$CONTENIDO" >> "$DESTINO"
    echo "[OK] Creado en $CARPETA/"
fi

echo "=== Categoría: $CATEGORIA ==="