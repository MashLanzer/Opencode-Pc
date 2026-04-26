#!/usr/bin/env bash
# Auto-Restart — Reinicia servicios caídos
# Usage: auto-restart.sh [start|stop|status|check|add|remove|list]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
LOG_FILE="/home/mash/Opencode/Base/logs/auto-restart.log"
PID_FILE="/tmp/auto-restart.pid"
DATA_DIR="$AI_ROOT/.auto-restart"
mkdir -p "$DATA_DIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }
trap 'log "[ERROR] Fallo en el auto-restart"' ERR

SERVICES_FILE="$DATA_DIR/services.txt"

# Servicios por defecto
if [ ! -f "$SERVICES_FILE" ]; then
    cat > "$SERVICES_FILE" << 'EOF'
ollama|nohup /home/mash/.local/bin/ollama serve|/home/mash/.local/bin/ollama
conky|conky -d|/usr/bin/conky
plank|plank &|/usr/bin/plank
EOF
fi

check_service() {
    local NAME="$1"
    local START="$3"
    
    if pgrep -x "$NAME" >/dev/null 2>&1; then
        return
    else
        log "[WARN] $NAME caido - reiniciando..."
        eval "$START" >> "$LOG_FILE" 2>&1 &
        sleep 2
        if pgrep -x "$NAME" >/dev/null 2>&1; then
            log "[OK] $NAME reiniciado"
        else
            log "[ERROR] $NAME no pudo ser reiniciado"
        fi
    fi
}

check_all() {
    while IFS='|' read -r name check start; do
        [ -n "$name" ] || continue
        check_service "$name" "$check" "$start"
    done < "$SERVICES_FILE"
}

restart_loop() {
    while true; do
        check_all
        sleep 30
    done
}

case "${1:-check}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[WARN] Ya está corriendo"
            exit 0
        fi
        nohup bash -c "$(declare -f check_service; restart_loop)" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "[OK] Auto-restart iniciado (PID: $(cat $PID_FILE))"
        ;;
    stop)
        [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm "$PID_FILE"
        echo "[OK] Auto-restart detenido"
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[OK] Auto-restart corriendo (PID: $(cat $PID_FILE))"
        else
            echo "[INFO] No está corriendo"
        fi
        ;;
    check)
        check_all
        ;;
    *)
        echo "Usage: auto-restart.sh [start|stop|status|check|add|remove|list]"
        ;;
esac