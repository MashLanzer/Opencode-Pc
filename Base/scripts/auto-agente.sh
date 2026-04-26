#!/usr/bin/env bash
# Auto-Agente — Ejecuta tareas autonomously sin pedir confirmación
# Usage: auto-agente.sh [start|stop|status|run-once]

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

LOG_FILE="/home/mash/Opencode/Base/logs/auto-agente.log"
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
PID_FILE="/tmp/auto-agente.pid"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }
trap 'log "[ERROR] Fallo en el auto-agente"' ERR

# Asegurar que Ollama esté corriendo
ensure_ollama() {
    if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        log "[INFO] Iniciando Ollama..."
        nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
        sleep 5
    fi
}

# Ciclo principal del agente
agent_loop() {
    while true; do
        log "Auto-agente ciclo..."
        
        # 1. Revisar tareas pendientes
        /home/mash/Opencode/Base/scripts/task-runner.sh run >> "$LOG_FILE" 2>&1 || true
        
        # 2. Actualizar memoria
        /home/mash/Opencode/Base/scripts/actualizar-memoria-ia.sh >> "$LOG_FILE" 2>&1 || true
        
        # 3. Análisis de ser necesario
        ensure_ollama
        
        # Esperar 5 minutos antes del siguiente ciclo
        sleep 300
    done
}

case "${1:-status}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[WARN] Ya está corriendo"
            exit 0
        fi
        
        ensure_ollama
        nohup bash -c "$(declare -f ensure_ollama; agent_loop)" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "[OK] Auto-agente iniciado (PID: $(cat $PID_FILE))"
        ;;
        
    stop)
        [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm "$PID_FILE"
        echo "[OK] Auto-agente detenido"
        ;;
        
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[OK] Auto-agente corriendo (PID: $(cat $PID_FILE))"
        else
            echo "[INFO] Auto-agente no está corriendo"
        fi
        ;;
        
    run-once|run)
        ensure_ollama
        /home/mash/Opencode/Base/scripts/task-runner.sh run
        /home/mash/Opencode/Base/scripts/actualizar-memoria-ia.sh
        echo "[OK] Ciclo completado"
        ;;
        
    *)
        echo "Usage: auto-agente.sh [start|stop|status|run-once]"
        ;;
esac