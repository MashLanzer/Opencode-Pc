#!/usr/bin/env bash
# Cron Inteligente — Scheduler que aprende cuando trabajar
# Usage: cron-inteligente.sh [add|remove|list|run|learn|status]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
DATA_DIR="$AI_ROOT/.cron-inteligente"
mkdir -p "$DATA_DIR"

COMMAND="${1:-list}"

get_hour_score() {
    local HORA=$(date +%H)
    local ACTIVO="$DATA_DIR/activehours.txt"
    local ULTIMO="$DATA_DIR/history.txt"
    
    if [ -f "$ULTIMO" ] && grep -q "$(date +%Y-%m-%d)" "$ULTIMO"; then
        echo "85"
    elif [ -f "$ACTIVO" ]; then
        local SCORE=$(grep "^${HORA} " "$ACTIVO" 2>/dev/null | awk '{print $2}')
        if [ -n "$SCORE" ]; then
            echo "$SCORE"
        else
            echo "50"
        fi
    else
        echo "50"
    fi
}

should_run() {
    local SCORE=$(get_hour_score)
    local UMBRAL="${2:-60}"
    
    if [ "$SCORE" -ge "$UMBRAL" ]; then
        return 0
    else
        return 1
    fi
}

case "$COMMAND" in
    add)
        Tarea="${2:-}"
        COMANDO="${3:-}"
        CRON="${4:-}"
        
        if [ -z "$Tarea" ] || [ -z "$COMANDO" ]; then
            echo "Usage: cron-inteligente.sh add \"tarea\" \"comando\" [cron]"
            exit 1
        fi
        
        ID=$(date +%s)
        echo "$ID|$Tarea|$COMANDO|$CRON|active" > "$DATA_DIR/task_$ID.txt"
        echo "[OK] Tarea agregada: $Tarea"
        ;;
        
    remove)
        ID="$2"
        if [ -n "$ID" ]; then
            rm -f "$DATA_DIR/task_$ID.txt"
            echo "[OK] Removida"
        fi
        ;;
        
    list)
        echo "=== Tareas programadas ==="
        for f in "$DATA_DIR"/task_*.txt; do
            [ -f "$f" ] || continue
            IFS='|' read -r id task cmd cron status < "$f"
            echo "[$status] $task (cron: $cron)"
        done
        ;;
        
    run)
        echo "[INFO] Verificando si ejecutar..."
        
        if should_run; then
            echo "[OK] Ejecutando (score: $(get_hour_score))"
            for f in "$DATA_DIR"/task_*.txt; do
                [ -f "$f" ] || continue
                IFS='|' read -r id task cmd cron status < "$f"
                if [ "$status" = "active" ]; then
                    echo "[EJECUTANDO] $task"
                    eval "$cmd" 2>/dev/null || true
                fi
            done
            
            HORA=$(date +%H)
            echo "$(date +%Y-%m-%d) $HORA: actividad" >> "$DATA_DIR/history.txt"
        else
            echo "[SKIP] No es buen momento (score: $(get_hour_score))"
        fi
        ;;
        
    learn)
        echo "[INFO] Aprendiendo de historial..."
        
        if [ -f "$DATA_DIR/history.txt" ]; then
            awk '{print $2}' "$DATA_DIR/history.txt" | sort | uniq -c | \
            while read COUNT HORA; do
                SCORE=$((50 + COUNT * 10))
                [ "$SCORE" -gt "100" ] && SCORE=100
                echo "$HORA $SCORE" >> "$DATA_DIR/activehours.txt"
            done
        fi
        
        echo "[OK] Aprendido"
        ;;
        
    status)
        SCORE=$(get_hour_score)
        echo "=== Estado del Cron Inteligente ==="
        echo "Score actual: $SCORE/100"
        echo "Hora: $(date +%H:00)"
        ;;
        
    *)
        echo "Usage: cron-inteligente.sh [add|remove|list|run|learn|status]"
        ;;
esac