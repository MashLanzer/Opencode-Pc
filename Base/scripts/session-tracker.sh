#!/usr/bin/env bash
# Session Tracker — Track de tiempo por proyecto
# Usage: session-tracker.sh [start|stop|status|report|list|project]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
HISTORIAL="$AI_ROOT/session-history.md"
SESSION_FILE="/tmp/session_activa.txt"
PROYECTO_ACTUAL=""

# Detectar proyecto activo
detectar_proyecto() {
    # Por carpeta git
    local GIT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$GIT_DIR" ]; then
        basename "$GIT_DIR"
        return
    fi
    
    # Por carpeta actual
    pwd | xargs basename
}

case "${1:-status}" in
    start)
        PROYECTO="${2:-$(detectar_proyecto)}"
        
        if [ -f "$SESSION_FILE" ]; then
            echo "[WARN] Sesión ya activa"
            cat "$SESSION_FILE"
            exit 0
        fi
        
        HORA=$(date '+%Y-%m-%d %H:%M')
        echo "proyecto:$PROYECTO" > "$SESSION_FILE"
        echo "inicio:$HORA" >> "$SESSION_FILE"
        
        echo "[OK] Sesión iniciada: $PROYECTO a las $HORA"
        ;;
        
    stop)
        if [ ! -f "$SESSION_FILE" ]; then
            echo "[WARN] No hay sesión activa"
            exit 0
        fi
        
        PROYECTO=$(grep "^proyecto:" "$SESSION_FILE" | cut -d: -f2)
        INICIO=$(grep "^inicio:" "$SESSION_FILE" | cut -d: -f2)
        FIN=$(date '+%Y-%m-%d %H:%M')
        
        # Calcular duración
        INI_SEC=$(date -d "$INICIO" +%s 2>/dev/null || echo 0)
        FIN_SEC=$(date -d "$FIN" +%s)
        DURACION=$((FIN_SEC - INI_SEC))
        HORAS=$((DURACION / 3600))
        MINUTOS=$(((DURACION % 3600) / 60))
        
        # Escribir en historial
        echo "## $(date '+%Y-%m-%d')" >> "$HISTORIAL"
        echo "### $PROYECTO" >> "$HISTORIAL"
        echo "- Inicio: $INICIO | Fin: $FIN | Total: ${HORAS}h ${MINUTOS}m" >> "$HISTORIAL"
        
        rm "$SESSION_FILE"
        
        echo "[OK] Sesión guardada: $PROYECTO ${HORAS}h ${MINUTOS}m"
        ;;
        
    status)
        if [ -f "$SESSION_FILE" ]; then
            PROYECTO=$(grep "^proyecto:" "$SESSION_FILE" | cut -d: -f2)
            INICIO=$(grep "^inicio:" "$SESSION_FILE" | cut -d: -f2)
            echo "[SESION ACTIVA] $PROYECTO desde $INICIO"
        else
            echo "[INFO] Sin sesión activa"
        fi
        ;;
        
    list)
        echo "=== Historial de Sesiones ==="
        tail -20 "$HISTORIAL" 2>/dev/null || echo "Sin historial"
        ;;
        
    report)
        echo "=== Reporte de Tiempo (Gráfica ASCII) ==="
        # Extraer totales por proyecto
        grep "### " "$HISTORIAL" | sort | uniq | while read -r p; do
            PROY="${p/### /}"
            TOTAL_MIN=0
            # Sumar minutos (simplificado)
            while read -r line; do
                if [[ $line == *"Total:"* ]]; then
                    H=$(echo "$line" | grep -oE "[0-9]+h" | tr -d 'h') || H=0
                    M=$(echo "$line" | grep -oE "[0-9]+m" | tr -d 'm') || M=0
                    TOTAL_MIN=$((TOTAL_MIN + (H*60) + M))
                fi
            done < <(grep -A1 "$p" "$HISTORIAL")
            
            # Graficar
            printf "%-20s |" "$PROY"
            for i in $(seq 1 $((TOTAL_MIN / 30))); do printf "█"; done
            printf " %dh %dm\n" $((TOTAL_MIN / 60)) $((TOTAL_MIN % 60))
        done
        ;;
        
    project)
        PROYECTO="${2:-}"
        
        if [ -z "$PROYECTO" ]; then
            echo "Usage: session-tracker.sh project \"nombre\""
            exit 1
        fi
        
        # Buscar tiempo por proyecto
        echo "=== Tiempo en $PROYECTO ==="
        grep -A1 "### $PROYECTO" "$HISTORIAL" | grep -v "### " | head -10
        ;;
        
    *)
        echo "Usage: session-tracker.sh [start|stop|status|list|report|project]"
        ;;
esac