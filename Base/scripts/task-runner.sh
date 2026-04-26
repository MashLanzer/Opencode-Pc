#!/usr/bin/env bash
# Task Runner — Sistema de tareas programadas
# Usage: task-runner.sh [add|list|run|done|cron]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
TASKS_DIR="$AI_ROOT/.tasks"
LOG_FILE="/home/mash/Opencode/Base/logs/task-runner.log"
mkdir -p "$TASKS_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

trap 'log "[ERROR] Fallo en la tarea"' ERR

COMMAND="${1:-list}"

case "$COMMAND" in
    add)
        # Usage: task-runner.sh add "descripcion" "comando" [cron] [proyecto]
        DESCRIPCION="${2:-}"
        COMANDO="${3:-}"
        CRON="${4:-daily}"
        PROYECTO="${5:-general}"
        
        if [ -z "$DESCRIPCION" ] || [ -z "$COMANDO" ]; then
            log "[ERROR] Uso incorrecto: task-runner.sh add \"desc\" \"cmd\""
            exit 1
        fi
        
        TASK_ID=$(date +%s)
        echo "$TASK_ID|$DESCRIPCION|$COMANDO|$CRON|$PROYECTO|pending" > "$TASKS_DIR/$TASK_ID.task"
        log "[OK] Tarea agregada: $DESCRIPCION"
        ;;
        
    list)
        echo "=== Tareas programadas ==="
        for f in "$TASKS_DIR"/*.task; do
            [ -f "$f" ] || continue
            IFS='|' read -r id desc cmd cron proj status < "$f"
            echo "[$status] $desc (cron: $cron, proyecto: $proj)"
        done
        ;;
        
    run)
        log "[INFO] Ejecutando tareas..."
        for task in "$TASKS_DIR"/*.task; do
            [ -f "$task" ] || continue
            IFS='|' read -r id desc cmd cron proj status < "$task"
            if [ "$status" = "pending" ]; then
                log "[EJECUTANDO] $desc"
                if eval "$cmd" >> "$LOG_FILE" 2>&1; then
                    log "[OK] $desc completada"
                    sed -i 's/pending/done/' "$task"
                else
                    log "[ERROR] $desc falló"
                fi
            fi
        done
        ;;
        
    done)
        TASK_ID="$2"
        if [ -f "$TASKS_DIR/$TASK_ID.task" ]; then
            sed -i 's/pending/done/' "$TASKS_DIR/$TASK_ID.task"
            log "[OK] Tarea $TASK_ID marcada como done"
        else
            log "[ERROR] Tarea $TASK_ID no encontrada"
        fi
        ;;
    *)
        echo "Comandos: add, list, run, done"
        ;;
esac