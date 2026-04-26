#!/usr/bin/env bash
# Agente de análisis con IA — Analiza notas y sugiere acciones
# Usage: analizar-notas.sh [nota]

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"
NOTA="${1:-$AI_ROOT/MEMORIA-PRINCIPAL.md}"

# Log directory
LOG_FILE="/home/mash/Opencode/Base/logs/analizar-notas.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

trap 'log "[ERROR] Fallo en el análisis"' ERR

# Asegurar Ollama
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log "[INFO] Iniciando Ollama..."
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

log "[INFO] Analizando nota: $NOTA"
CONTENIDO=$(cat "$NOTA" 2>/dev/null | head -30)

#Prompt de análisis
PROMPT="Responde en español. Resume en 2 lineas: $CONTENIDO"

echo "[INFO] Analizando con $MODEL..."

# Usar modo interactivo
RESPUESTA=$(echo "$PROMPT" | timeout 120 /home/mash/.local/bin/ollama run "$MODEL" 2>/dev/null)

echo "$RESPUESTA"