#!/usr/bin/env bash
# IA Diario — Genera entrada automática en revision-diaria.md
# Usage: ia-diario.sh [proyecto] [duracion]
# Se llama automáticamente desde session-tracker.sh stop

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
DIARIO="$AI_ROOT/revision-diaria.md"
LOG_FILE="/home/mash/Opencode/Base/logs/auto-agente.log"
MODEL="llama3.2:1b"
FECHA=$(date '+%Y-%m-%d')
HORA=$(date '+%H:%M')

PROYECTO="${1:-General}"
DURACION="${2:-desconocida}"

# Recopilar contexto del día
TAREAS_HOY=$(grep -E "^\- \[x\]" "$AI_ROOT/tareas-pendientes.md" 2>/dev/null | head -5 || echo "Sin tareas completadas")
ERRORES_HOY=$(grep "$(date '+%Y-%m-%d').*ERROR" "$LOG_FILE" 2>/dev/null | tail -3 || echo "Sin errores")
SESION_HOY=$(tail -5 "$AI_ROOT/session-history.md" 2>/dev/null || echo "Sin historial")

PROMPT="Genera una entrada de diario personal breve (máximo 4 líneas) en español para un desarrollador.
Proyecto trabajado: $PROYECTO
Tiempo dedicado: $DURACION
Tareas completadas hoy: $TAREAS_HOY
Errores encontrados: $ERRORES_HOY
Sesión: $SESION_HOY

Escribe solo el párrafo del diario, sin título, en primera persona, tono natural. Máximo 80 palabras."

RESUMEN=$(curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null \
    || echo "Sesión de trabajo completada en $PROYECTO. Duración: $DURACION.")

# Escribir en revision-diaria.md (acumula entradas del día)
{
    echo ""
    echo "## $FECHA — $HORA"
    echo ""
    echo "**Proyecto:** $PROYECTO | **Tiempo:** $DURACION"
    echo ""
    echo "$RESUMEN"
    echo ""
    echo "---"
} >> "$DIARIO"

echo "[OK] Diario actualizado ($FECHA)"

# Frase corta para hablar
FRASE_CORTA=$(echo "$RESUMEN" | head -1 | cut -c1-100)
/home/mash/Opencode/Base/scripts/hablar.sh "Sesión guardada. $FRASE_CORTA" 2>/dev/null || true
