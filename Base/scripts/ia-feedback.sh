#!/usr/bin/env bash
# IA Feedback — Optimiza las instrucciones de la IA
# Usage: ia feedback "comentario"

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

INSTRUCCIONES="/home/mash/Opencode/Base/docs/INSTRUCCIONES-IA.md"
FEEDBACK="$*"
MODEL="llama3.2:1b"

if [ -z "$FEEDBACK" ]; then
    echo "Usage: ia feedback \"tu comentario sobre cómo mejorar la IA\""
    exit 1
fi

echo "[INFO] Analizando feedback y reescribiendo instrucciones..."

# Leer actuales
ACTUALES=$(cat "$INSTRUCCIONES")

PROMPT="Eres el sistema de optimización de instrucciones.
Instrucciones actuales:
$ACTUALES

Comentario de usuario para mejorar el rendimiento:
$FEEDBACK

Reescribe las instrucciones para incorporar este feedback sin perder las reglas actuales. Responde SOLO con el nuevo archivo completo."

# Llamar a Ollama
NUEVAS=$(curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" | jq -r '.response' 2>/dev/null || echo "Error.")

# Guardar
echo "$NUEVAS" > "$INSTRUCCIONES"
echo "[OK] Instrucciones actualizadas correctamente."
echo "[INFO] Feedback registrado en /home/mash/Opencode/Base/logs/feedback.log"
echo "$FEEDBACK" >> "/home/mash/Opencode/Base/logs/feedback.log"