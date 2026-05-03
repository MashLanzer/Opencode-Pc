#!/usr/bin/env bash
# The Janitor — Identifica contradicciones e información obsoleta
# Usage: janitor.sh [scan]

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
LOG_FILE="/home/mash/Opencode/Base/logs/janitor.log"
MODEL="llama3.2:1b"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }

log "[INFO] El Janitor está escaneando contradicciones..."

# Recopilar contexto amplio: fechas, disco, ram, versiones, rutas
CONTEXTO=$(grep -rh -E "(disco|ram|versión|version|ruta|path|fecha|[0-9]{4}-[0-9]{2}-[0-9]{2})" \
    "$AI_ROOT" --include="*.md" | head -n 20)
PROMPT="Analiza este texto buscando datos contradictorios o información desactualizada (ej: diferentes capacidades de disco, versiones distintas del mismo software, fechas incoherentes):
$CONTEXTO

Si encuentras algo extraño, escribe una advertencia corta en español. Si todo está consistente, responde exactamente 'OK'."

# Llamar a Ollama
RESPUESTA=$(curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" | jq -r '.response' 2>/dev/null || echo "OK")

if [ "$RESPUESTA" != "OK" ]; then
    log "[ALERTA] Posible contradicción detectada: $RESPUESTA"
    /home/mash/Opencode/Base/scripts/hablar.sh "Atención, he detectado una posible contradicción en tus notas: $RESPUESTA"
else
    log "[OK] No se detectaron contradicciones."
fi