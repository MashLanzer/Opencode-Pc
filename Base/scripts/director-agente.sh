#!/usr/bin/env bash
# Director de Proyecto — Analiza productividad y reordena tareas
set -euo pipefail
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
TASKS="$AI_ROOT/tareas-pendientes.md"
SESSION="$AI_ROOT/session-history.md"

PROMPT="Analiza mis sesiones de trabajo ($SESSION) y mis tareas pendientes ($TAREAS).
Reordena las tareas pendientes para priorizar el proyecto donde he sido más productivo pero que aún tiene tareas activas.
Devuelve el contenido del archivo tareas-pendientes.md reordenado.
Solo devuelve el contenido del archivo, no expliques nada."

# Generar propuesta con Gemini
PROPUESTA=$(python3 /home/mash/Opencode/Base/scripts/ia-chat-engine.sh "$PROMPT")

# Actualizar si la propuesta es válida
if [[ "$PROPUESTA" == *"-"* ]]; then
    echo "$PROPUESTA" > "$TASKS"
    echo "[OK] Tareas reordenadas por productividad."
else
    echo "[INFO] Sin cambios necesarios."
fi