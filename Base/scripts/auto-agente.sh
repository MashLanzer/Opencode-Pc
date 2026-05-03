#!/usr/bin/env bash
# Auto-Agente — Ejecuta tareas autonomously
# Usage: auto-agente.sh [start|stop|status|run-once]

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

LOG_FILE="/home/mash/Opencode/Base/logs/auto-agente.log"
BASE_DIR="/home/mash/Opencode/Base/scripts"
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
    log "Auto-agente iniciado."
    /home/mash/Opencode/Base/scripts/hablar.sh "Hola Mash, sistema operativo encendido. Iniciando ciclo autónomo."
    
    while true; do
        log "Auto-agente ciclo..."
        
        # 1. Tareas programadas
        "$BASE_DIR/task-runner.sh" run >> "$LOG_FILE" 2>&1 || true
        
        # 2. Análisis de mantenimiento
        "$BASE_DIR/janitor.sh" >> "$LOG_FILE" 2>&1 || true
        
        # 3. Procesar Inbox
        "$BASE_DIR/inbox-agente.sh" >> "$LOG_FILE" 2>&1 || true
        
        # 4. Actualizar memoria
        "$BASE_DIR/actualizar-memoria-ia.sh" >> "$LOG_FILE" 2>&1 || true

        # 5. Re-indexar RAG si hay archivos nuevos o modificados
        if python3 /home/mash/Opencode/Base/python/indexador.py check 2>/dev/null | grep -q "re-index"; then
            log "[RAG] Cambios detectados — re-indexando..."
            python3 /home/mash/Opencode/Base/python/indexador.py index >> "$LOG_FILE" 2>&1 || true
        fi

        # 6. Análisis/Conversación proactiva
        ensure_ollama
        
        # Esperar 10 minutos
        sleep 600
    done
}

case "${1:-status}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[WARN] Ya está corriendo"
            exit 0
        fi
        
        ensure_ollama
        nohup bash -c "
BASE_DIR='$BASE_DIR'
LOG_FILE='$LOG_FILE'
$(declare -f log ensure_ollama agent_loop)
agent_loop
" >> "$LOG_FILE" 2>&1 &
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
        "$BASE_DIR/task-runner.sh" run
        "$BASE_DIR/janitor.sh"
        "$BASE_DIR/inbox-agente.sh"
        "$BASE_DIR/actualizar-memoria-ia.sh"
        if python3 /home/mash/Opencode/Base/python/indexador.py check 2>/dev/null | grep -q "re-index"; then
            echo "[RAG] Re-indexando..."
            python3 /home/mash/Opencode/Base/python/indexador.py index
        fi
        echo "[OK] Ciclo completado"
        ;;
        
    *)
        echo "Usage: auto-agente.sh [start|stop|status|run-once]"
        ;;
esac