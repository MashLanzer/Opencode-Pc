#!/usr/bin/env bash
# IA TUI Dashboard
# Requiere: whiptail

if ! command -v whiptail &> /dev/null; then
    echo "[ERROR] whiptail no instalado. Ejecuta: sudo apt install whiptail"
    exit 1
fi

RED='\e[31m'
GREEN='\e[32m'
RESET='\e[0m'

get_status_color() {
    if pgrep -x "$1" >/dev/null; then
        echo -e "${GREEN}Corriendo${RESET}"
    else
        echo -e "${RED}Caído${RESET}"
    fi
}

while true; do
    # Dashboard rápido con colores
    MSG="Sistema de IA Memory
-----------------------
Auto-agente: $(get_status_color "auto-agente.sh")
Ollama:      $(get_status_color "ollama")
Monitor:     $(get_status_color "monitor-sistema.sh")
-----------------------
Disco: $(df / | awk 'NR==2{print $5}')
RAM:   $(free | awk '/Mem:/{print int($3/$2*100)}')%
"

    CHOICE=$(whiptail --title "IA Memory Dashboard" --menu "$MSG" 20 60 10 \
        "1" "Estado del sistema" \
        "2" "Analizar notas" \
        "3" "Ver tareas" \
        "4" "Ejecutar mantenimiento" \
        "5" "Ejecutar RAG search" \
        "Q" "Salir" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1)
            STATUS=$(/home/mash/Opencode/Base/scripts/ia.sh status)
            whiptail --msgbox "$STATUS" 20 60
            ;;
        2)
            NOTA=$(whiptail --inputbox "Introduce ruta de nota (ej: Notas/nota_...md):" 10 60 3>&1 1>&2 2>&3)
            if [ -n "$NOTA" ]; then
                /home/mash/Opencode/Base/scripts/ia.sh analyze "$NOTA" > /tmp/tui_out
                whiptail --msgbox "$(cat /tmp/tui_out)" 20 60
            fi
            ;;
        3)
            TASKS=$(/home/mash/Opencode/Base/scripts/task-runner.sh list)
            whiptail --msgbox "$TASKS" 20 60
            ;;
        4)
            /home/mash/Opencode/Base/scripts/mantenimiento-agente.sh
            whiptail --msgbox "Mantenimiento completado" 10 60
            ;;
        5)
            QUERY=$(whiptail --inputbox "Buscar semánticamente:" 10 60 3>&1 1>&2 2>&3)
            if [ -n "$QUERY" ]; then
                python3 /home/mash/Opencode/Base/python/buscador.py "$QUERY" > /tmp/tui_out
                whiptail --msgbox "$(cat /tmp/tui_out)" 20 60
            fi
            ;;
        Q)
            break
            ;;
    esac
done
clear