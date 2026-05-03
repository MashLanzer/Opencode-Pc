#!/usr/bin/env bash
# Atajo de teclado: Super+V — toggle VEXA UI o iniciar si no corre
# Agregar en Cinnamon: Sistema > Teclado > Atajos > Lanzador personalizado

VEXA_URL="http://localhost:8765"
PID_FILE="/tmp/vexa.pid"
SERVICE="vexa.service"

_running() {
    systemctl --user is-active --quiet "$SERVICE" 2>/dev/null || \
    { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }
}

if _running; then
    xdg-open "$VEXA_URL" 2>/dev/null
else
    notify-send "VEXA" "Iniciando..." --app-name="VEXA" 2>/dev/null
    bash /home/mash/Opencode/Base/scripts/vexa-manager.sh start
    sleep 2
    xdg-open "$VEXA_URL" 2>/dev/null
fi
