#!/usr/bin/env bash
# Agente de análisis con IA — Analiza notas y sugiere acciones (Mejorado con Context Engine)
# Usage: analizar-notas.sh [nota]

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"
LOG_FILE="/home/mash/Opencode/Base/logs/analizar-notas.log"
SESSION_FILE="/tmp/session_activa.txt"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }
trap 'log "[ERROR] Fallo en el análisis"' ERR

# 1. Detectar contexto
PROYECTO=$(grep "^proyecto:" "$SESSION_FILE" 2>/dev/null | cut -d: -f2 || echo "general")
PROJ_CONTEXT=$(find "$AI_ROOT/Proyectos" -name "*$PROYECTO*" -exec cat {} + 2>/dev/null | head -c 2000)

NOTA="${1:-$AI_ROOT/MEMORIA-PRINCIPAL.md}"

# Asegurar Ollama
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

log "[INFO] Analizando nota: $NOTA. Contexto proyecto: $PROYECTO"
CONTENIDO=$(cat "$NOTA" 2>/dev/null | head -30)

# Prompt mejorado con Contexto
PROMPT="Eres un asistente IA experto. Analiza la siguiente nota y el contexto del proyecto actual.

Contexto del proyecto '$PROYECTO':
$PROJ_CONTEXT

Nota a analizar:
$CONTENIDO

Proporciona:
1. Resumen breve
2. Sugerencias de acciones concretas relacionadas con este proyecto
3. Estado general

Responde en español."

# Enviar a Ollama
RESPUESTA=$(echo "$PROMPT" | timeout 120 /home/mash/.local/bin/ollama run "$MODEL" 2>/dev/null)

echo "=== Análisis con Contexto: $PROYECTO ==="
echo "$RESPUESTA"