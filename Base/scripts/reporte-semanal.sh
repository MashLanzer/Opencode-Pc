#!/usr/bin/env bash
# Reporte Ejecutivo Semanal
# Usage: reporte-semanal.sh

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
REPORT_DIR="$AI_ROOT/Conversaciones/Reportes"
mkdir -p "$REPORT_DIR"

FECHA_REPORT=$(date '+%Y-%m-%d')
REPORT_FILE="$REPORT_DIR/Reporte_Semanal_$FECHA_REPORT.md"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "/home/mash/Opencode/Base/logs/reporte.log"; }

log "[INFO] Generando reporte semanal..."

# 1. Recopilar datos
SESIONES=$(cat "$AI_ROOT/session-history.md" 2>/dev/null | tail -100)
TAREAS=$(grep "\[x\]" "$AI_ROOT/tareas-pendientes.md" 2>/dev/null | tail -20)
RESUMEN_GENERAL=$(cat "$AI_ROOT/Conversaciones/_resumen-general.md" 2>/dev/null | tail -50)

# 2. Prompt
PROMPT="Analiza esta actividad de la semana:

Sesiones: $SESIONES
Tareas completadas: $TAREAS
Resúmenes previos: $RESUMEN_GENERAL

Genera un reporte ejecutivo de máximo 500 palabras incluyendo:
1. Resumen de productividad
2. Proyectos que avanzaron más
3. Recomendaciones para la próxima semana.
Sé profesional y objetivo."

# 3. Generar
RESPUESTA=$(echo "$PROMPT" | timeout 300 /home/mash/.local/bin/ollama run "llama3.2:1b" 2>/dev/null)

# 4. Guardar
echo "# Reporte Ejecutivo Semanal — $FECHA_REPORT" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "$RESPUESTA" >> "$REPORT_FILE"

log "[OK] Reporte generado: $REPORT_FILE"
echo "=== Reporte generado: $REPORT_FILE ==="