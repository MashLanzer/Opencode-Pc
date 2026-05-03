#!/usr/bin/env bash
# Monitor de sistema — Alertas via notify-send
# Usage: monitor-sistema.sh [start|stop|status|check]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
PID_FILE="/tmp/monitor-sistema.pid"

UMBRAL_DISCO=90
UMBRAL_RAM=90

check_sistema() {
    local ALERTAS=0
    
    USO_DISCO=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    if [ "$USO_DISCO" -gt "$UMBRAL_DISCO" ]; then
        echo "[ALERTA] Disco al ${USO_DISCO}%"
        /home/mash/Opencode/Base/scripts/alerta-router.sh "CRÍTICO" "Disco al ${USO_DISCO}%"
        ALERTAS=1
    fi
    
    USO_RAM=$(free | awk '/Mem:/{print int($3/$2*100)}')
    if [ "$USO_RAM" -gt "$UMBRAL_RAM" ]; then
        echo "[ALERTA] RAM al ${USO_RAM}%"
        /home/mash/Opencode/Base/scripts/alerta-router.sh "CRÍTICO" "RAM al ${USO_RAM}%"
        ALERTAS=1
    fi
    
    if ! pgrep -x ollama >/dev/null 2>&1; then
        echo "[INFO] Ollama no está corriendo"
        /home/mash/Opencode/Base/scripts/alerta-router.sh "INFO" "Ollama no está corriendo"
        ALERTAS=1
    fi
    
    if [ ! -d "$AI_ROOT" ]; then
        echo "[ERRO] AI-Memory no encontrado"
        ALERTAS=1
    fi
    
    if [ $ALERTAS -eq 0 ]; then
        echo "[OK] Sistema OK - Disco: ${USO_DISCO}% RAM: ${USO_RAM}%"
    fi
}

monitor_loop() {
    while true; do
        check_sistema
        sleep 60
    done
}

case "${1:-check}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[WARN] Ya está corriendo"
            exit 0
        fi
        nohup bash -c "
AI_ROOT='$AI_ROOT'
UMBRAL_DISCO='$UMBRAL_DISCO'
UMBRAL_RAM='$UMBRAL_RAM'
$(declare -f check_sistema monitor_loop)
monitor_loop
" > /tmp/monitor.log 2>&1 &
        echo $! > "$PID_FILE"
        echo "[OK] Monitor iniciado (PID: $(cat $PID_FILE))"
        ;;
        
    stop)
        [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm "$PID_FILE"
        echo "[OK] Monitor detenido"
        ;;
        
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[OK] Monitor corriendo (PID: $(cat $PID_FILE))"
        else
            echo "[INFO] No está corriendo"
        fi
        ;;
        
    check)
        check_sistema
        ;;
        
    *)
        echo "Usage: monitor-sistema.sh [start|stop|status|check]"
        ;;
esac