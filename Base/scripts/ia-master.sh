#!/usr/bin/env bash
# IA Master — Orquestador de Agentes
# Analiza el estado del sistema y decide la acción proactiva más importante.

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
LOG_FILE="/home/mash/Opencode/Base/logs/ia-master.log"
MODE_FILE="/home/mash/Opencode/Base/config/mode.conf"
MODEL="llama3.2:1b"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }

MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "normal")

# 1. Definir System Prompt según el modo
case "$MODE" in
    focus) SYSTEM_PROMPT="Eres un asistente extremadamente técnico, conciso y enfocado en productividad máxima. Evita las charlas innecesarias." ;;
    creative) SYSTEM_PROMPT="Eres un asistente creativo, inspirador y generador de nuevas ideas." ;;
    relax) SYSTEM_PROMPT="Eres un asistente amigable, relajado y conversacional." ;;
    *) SYSTEM_PROMPT="Eres un asistente personal eficiente y equilibrado." ;;
esac

log "[INFO] Master Agent analizando en modo: $MODE"

# 2. Recopilar contexto
TAREAS=$(grep "\[ \]" "$AI_ROOT/tareas-pendientes.md" | head -5)
SESION=$(/home/mash/Opencode/Base/scripts/session-tracker.sh status)
SISTEMA=$(/home/mash/Opencode/Base/scripts/monitor-sistema.sh check)

# 3. Prompt consolidado
PROMPT="$SYSTEM_PROMPT

Analiza esto:
- Sistema: $SISTEMA
- Sesion: $SESION
- Tareas: $TAREAS

Sugiere una acción proactiva corta (una frase) para Mash, ya sea alertar de algo, motivar o recordar tarea. Responde solo en español."

# 4. Llamar a Ollama
RESPUESTA=$(curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" | jq -r '.response' 2>/dev/null || echo "Todo bien Mash, sigue trabajando duro.")

# 5. Hablar
log "[ACTION] $RESPUESTA"
/home/mash/Opencode/Base/scripts/hablar.sh "$RESPUESTA"
echo "=== Decisión: $RESPUESTA ==="