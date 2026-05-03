#!/usr/bin/env bash
# IA Pomodoro — Timer Pomodoro con cambio automático de modo
# Usage: ia-pomodoro.sh [start|stop|skip|status]

set -uo pipefail

BASE_DIR="/home/mash/Opencode/Base/scripts"
CONFIG_DIR="/home/mash/Opencode/Base/config"
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODE_FILE="$CONFIG_DIR/mode.conf"
PID_FILE="/tmp/ia-pomodoro.pid"
STATE_FILE="/tmp/ia-pomodoro-state.txt"
HISTORIAL="$AI_ROOT/session-history.md"

DURACION_FOCO=25     # minutos
DURACION_DESCANSO=5  # minutos
DURACION_LARGA=15    # minutos cada 4 pomodoros

hablar() { "$BASE_DIR/hablar.sh" "$1" 2>/dev/null || true; }
notif()  { notify-send "🍅 Pomodoro" "$1" 2>/dev/null || true; }

set_modo() {
    echo "$1" > "$MODE_FILE"
}

pomodoro_loop() {
    local COUNT=0

    hablar "Iniciando sesión Pomodoro. Primer bloque de enfoque de $DURACION_FOCO minutos."
    notif "Sesión iniciada"

    while true; do
        COUNT=$((COUNT + 1))
        echo "fase:foco" > "$STATE_FILE"
        echo "bloque:$COUNT" >> "$STATE_FILE"
        echo "inicio:$(date '+%H:%M')" >> "$STATE_FILE"

        set_modo focus
        hablar "Bloque $COUNT de enfoque. Tienes $DURACION_FOCO minutos. A trabajar, Mash."
        notif "Bloque $COUNT — Foco ($DURACION_FOCO min)"

        sleep $((DURACION_FOCO * 60))

        # Verificar si fue saltado (state_file se habrá borrado)
        [ ! -f "$STATE_FILE" ] && break

        echo "fase:descanso" > "$STATE_FILE"

        if [ $((COUNT % 4)) -eq 0 ]; then
            set_modo relax
            hablar "Completaste 4 bloques. Tómate un descanso largo de $DURACION_LARGA minutos. Bien hecho."
            notif "Descanso largo — $DURACION_LARGA min"
            sleep $((DURACION_LARGA * 60))
        else
            set_modo relax
            hablar "Bloque $COUNT completado. Descanso de $DURACION_DESCANSO minutos."
            notif "Descanso — $DURACION_DESCANSO min"
            sleep $((DURACION_DESCANSO * 60))
        fi

        [ ! -f "$STATE_FILE" ] && break

        set_modo normal
    done

    # Guardar en historial
    {
        echo ""
        echo "## $(date '+%Y-%m-%d') — Pomodoro"
        echo "- Bloques completados: $COUNT"
        echo "- Tiempo de foco: $((COUNT * DURACION_FOCO)) min"
    } >> "$HISTORIAL"

    set_modo normal
    rm -f "$STATE_FILE" "$PID_FILE"
    hablar "Sesión Pomodoro finalizada. Completaste $COUNT bloques de trabajo."
    notif "Sesión finalizada — $COUNT bloques"
}

case "${1:-status}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "[WARN] Pomodoro ya está corriendo (PID: $(cat "$PID_FILE"))"
            exit 0
        fi
        nohup bash -c "
BASE_DIR='$BASE_DIR'
CONFIG_DIR='$CONFIG_DIR'
AI_ROOT='$AI_ROOT'
MODE_FILE='$MODE_FILE'
PID_FILE='$PID_FILE'
STATE_FILE='$STATE_FILE'
HISTORIAL='$HISTORIAL'
DURACION_FOCO=$DURACION_FOCO
DURACION_DESCANSO=$DURACION_DESCANSO
DURACION_LARGA=$DURACION_LARGA
$(declare -f hablar notif set_modo pomodoro_loop)
pomodoro_loop
" > /tmp/pomodoro.log 2>&1 &
        echo $! > "$PID_FILE"
        echo "[OK] Pomodoro iniciado (PID: $(cat "$PID_FILE"))"
        ;;

    stop)
        if [ -f "$PID_FILE" ]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null || true
            rm -f "$PID_FILE" "$STATE_FILE"
            echo "normal" > "$MODE_FILE"
        fi
        echo "[OK] Pomodoro detenido"
        ;;

    skip)
        if [ ! -f "$STATE_FILE" ]; then
            echo "[INFO] No hay fase activa que saltar"
            exit 0
        fi
        FASE=$(grep "^fase:" "$STATE_FILE" | cut -d: -f2)
        echo "[OK] Saltando fase: $FASE"
        # Matar el sleep del loop sin matar el proceso padre
        pkill -f "sleep $((DURACION_FOCO * 60))" 2>/dev/null || true
        pkill -f "sleep $((DURACION_DESCANSO * 60))" 2>/dev/null || true
        pkill -f "sleep $((DURACION_LARGA * 60))" 2>/dev/null || true
        ;;

    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            BLOQUE=$(grep "^bloque:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "?")
            FASE=$(grep "^fase:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "?")
            INICIO=$(grep "^inicio:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "?")
            MODO=$(cat "$MODE_FILE" 2>/dev/null || echo "?")
            echo "[OK] Pomodoro corriendo — Bloque $BLOQUE | Fase: $FASE | Desde: $INICIO | Modo: $MODO"
        else
            echo "[INFO] Pomodoro no está corriendo"
        fi
        ;;

    *)
        echo "Usage: ia-pomodoro.sh [start|stop|skip|status]"
        ;;
esac
