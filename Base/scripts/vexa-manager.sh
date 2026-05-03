#!/usr/bin/env bash
# Gestiona el proceso VEXA — con soporte systemd + notify-send
# Usage: vexa-manager.sh [start|stop|status|restart|ui|logs|enable|disable] [--no-voice]

VEXA_DIR="/home/mash/Opencode/VEXA"
PID_FILE="/tmp/vexa.pid"
LOG_FILE="$VEXA_DIR/logs/vexa.log"
SERVICE="vexa.service"

_notify() {
    notify-send --app-name="VEXA" --icon="$VEXA_DIR/ui/vexa-icon.svg" "$1" "$2" 2>/dev/null || true
}

_systemd_available() {
    systemctl --user is-system-running &>/dev/null
}

_systemd_running() {
    systemctl --user is-active --quiet "$SERVICE" 2>/dev/null
}

_pid_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

_running() {
    _systemd_running || _pid_running
}

case "${1:-status}" in
    start)
        if _running; then
            echo "[WARN] VEXA ya está corriendo"
            exit 0
        fi
        shift
        mkdir -p "$VEXA_DIR/logs"

        if _systemd_available && systemctl --user list-unit-files "$SERVICE" &>/dev/null; then
            # Usar systemd si el servicio está instalado
            systemctl --user start "$SERVICE"
            sleep 1
            if _systemd_running; then
                echo "[OK] VEXA iniciado via systemd"
                echo "     UI  → http://localhost:8765"
                _notify "VEXA iniciada" "Sistema de voz activo. Di 'oye VEXA' para hablar."
            else
                echo "[ERROR] Falló el inicio. Revisa: journalctl --user -u vexa -n 20"
                exit 1
            fi
        else
            # Fallback: proceso directo
            nohup python3 "$VEXA_DIR/vexa_core.py" "$@" >> "$LOG_FILE" 2>&1 &
            echo $! > "$PID_FILE"
            sleep 1
            if _pid_running; then
                echo "[OK] VEXA iniciado (PID: $(cat "$PID_FILE"))"
                echo "     UI  → http://localhost:8765"
                _notify "VEXA iniciada" "Sistema de voz activo."
            else
                echo "[ERROR] VEXA no pudo arrancar. Revisa: tail -20 $LOG_FILE"
                exit 1
            fi
        fi
        ;;

    stop)
        if _systemd_running; then
            systemctl --user stop "$SERVICE"
            echo "[OK] VEXA detenida (systemd)"
        elif _pid_running; then
            kill "$(cat "$PID_FILE")" 2>/dev/null
            rm -f "$PID_FILE"
            echo "[OK] VEXA detenida"
        else
            echo "[INFO] VEXA no estaba corriendo"
        fi
        ;;

    restart)
        "$0" stop; sleep 1; shift; "$0" start "$@"
        ;;

    status)
        if _systemd_running; then
            echo "[OK] VEXA corriendo (systemd)"
            systemctl --user status "$SERVICE" --no-pager -l | grep -E "Active:|Main PID:" | sed 's/^/     /'
        elif _pid_running; then
            echo "[OK] VEXA corriendo (PID: $(cat "$PID_FILE"))"
        else
            echo "[INFO] VEXA no está corriendo"
        fi
        echo "     UI  → http://localhost:8765"
        ;;

    enable)
        systemctl --user daemon-reload
        systemctl --user enable "$SERVICE"
        systemctl --user enable vexa-hud.service 2>/dev/null || true
        echo "[OK] VEXA + HUD habilitados — arrancarán con tu sesión"
        echo "     Para iniciar ahora: ia vexa start"
        ;;

    disable)
        systemctl --user disable "$SERVICE"
        systemctl --user disable vexa-hud.service 2>/dev/null || true
        echo "[OK] VEXA deshabilitada del arranque automático"
        ;;

    hud)
        # Lanzar HUD manual en background
        shift
        python3 /home/mash/Opencode/VEXA/hud.py "$@" &
        echo "[OK] HUD lanzado (PID: $!)"
        ;;

    ui)
        xdg-open "http://localhost:8765" 2>/dev/null \
            || echo "Panel VEXA → http://localhost:8765"
        ;;

    logs)
        if _systemd_running; then
            journalctl --user -u "$SERVICE" -f --no-pager
        else
            tail -f "$LOG_FILE"
        fi
        ;;

    notify)
        # Uso interno: ia vexa notify "titulo" "mensaje"
        _notify "${2:-VEXA}" "${3:-}"
        ;;

    *)
        echo "Usage: ia vexa [start|stop|status|restart|enable|disable|ui|logs]"
        echo "       ia vexa start [--no-voice|--no-ui|--no-wake]"
        ;;
esac
