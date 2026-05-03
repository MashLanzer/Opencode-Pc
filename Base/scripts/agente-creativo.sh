#!/usr/bin/env bash
# Agente Creativo — Genera ideas proactivamente
# Usage: agente-creativo.sh [proyecto]

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
DRAFT_DIR="$AI_ROOT/Notas/drafts"
MODEL="llama3.2:1b"
LOG_FILE="/home/mash/Opencode/Base/logs/agente-creativo.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }

PROYECTO="${1:-}"

# 1. Leer contexto del proyecto
PROJ_FILE=$(find "$AI_ROOT/Proyectos" -name "*$PROYECTO*" | head -1 || echo "$AI_ROOT/Proyectos/_indice-proyectos.md")
CONTEXTO=$(cat "$PROJ_FILE" 2>/dev/null | head -n 50)

log "[INFO] Generando ideas creativas para: ${PROYECTO:-general}"

# 2. Prompt creativo
PROMPT="Eres un socio creativo. Basado en este proyecto:
$CONTEXTO

Genera 3 ideas innovadoras, mecánicas o soluciones creativas para avanzar en este proyecto.
Sé visionario y atrevido. Responde en español."

# 3. Llamar a Ollama
RESPUESTA=$(curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" | jq -r '.response' 2>/dev/null || echo "No pude generar ideas.")

# 4. Guardar
FECHA=$(date '+%Y%m%d')
RUTA="$DRAFT_DIR/Creatividad_$PROYECTO_$FECHA.md"
echo "# Lluvia de ideas: $PROYECTO" > "$RUTA"
echo "" >> "$RUTA"
echo "$RESPUESTA" >> "$RUTA"

log "[OK] Ideas generadas en $RUTA"
/home/mash/Opencode/Base/scripts/hablar.sh "Mash, he tenido algunas ideas creativas para tu proyecto. Revisa el borrador en la carpeta de Notas."