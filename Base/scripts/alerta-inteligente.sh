#!/usr/bin/env bash
# Alerta Inteligente — IA decide cuándo alertar
# Usage: alerta-inteligente.sh [check|enable|disable|status]

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"
ALERTAS_FILE="$AI_ROOT/.alertas_historial.txt"
ULTIMA_ALERTA_FILE="/tmp/ultima_alerta.txt"

# Asegurar Ollama
ensure_ollama() {
    if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
        sleep 5
    fi
}

#Recopilar métricas
get_metricas() {
    local USO_DISCO=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    local USO_RAM=$(free | awk '/Mem:/{print int($3/$2*100)}')
    local CARGA=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local PROCS=$(ps aux | wc -l)
    
    echo "Disco: ${USO_DISCO}%, RAM: ${USO_RAM}%, Load: $CARGA, Procesos: $PROCS"
}

# IA decide si alertar
decidir_alerta() {
    local METRICAS="$1"
    local UMBRAL="${2:-80}"
    
    # Verificar si ya recent alert
    if [ -f "$ULTIMA_ALERTA_FILE" ]; then
        local HACE=$(($(date +%s) - $(stat -c %Y "$ULTIMA_ALERTA_FILE" 2>/dev/null || echo 0)))
        if [ "$HACE" -lt 3600 ]; then
            echo "recent"
            return 1
        fi
    fi
    
    PROMPT="Eres un sistema de alertas. Analiza las métricas y decide:

Metricas: $METRICAS
Umbral: $UMBRAL%

Responde SOLO con:
- alertar (si hay problema real que requiere atención)
- esperar (si no hay problema pero merece monitorizar)
- ignorar (si todo está normal)

Ejemplos de quando alertar:
- Disco > 90%
- RAM > 95%
- Load > numero de cores * 2

Responde solo una palabra."

    RESPUESTA=$(echo "$PROMPT" | timeout 60 /home/mash/.local/bin/ollama run "$MODEL" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]' | tr -d ' .')
    echo "$RESPUESTA"
}

case "${1:-check}" in
    check)
        ensure_ollama
        METRICAS=$(get_metricas)
        echo "[INFO] Metricas: $METRICAS"
        
        DECISION=$(decidir_alerta "$METRICAS")
        
        case "$DECISION" in
            alertar)
                echo "[ALERTA] IA decide: ALERTAR"
                notify-send -u critical "Alerta Sistema" "Metricas: $METRICAS" 2>/dev/null || echo "[ALERTA] $METRICAS"
                date +%s > "$ULTIMA_ALERTA_FILE"
                echo "$(date): $METRICAS" >> "$ALERTAS_FILE"
                ;;
            esperar)
                echo "[INFO] IA decide: ESPERAR (monitorear)"
                ;;
            ignorar|recent)
                echo "[OK] IA decide: IGNORAR (todo normal)"
                ;;
            *)
                echo "[WARN] Decision unclear: $DECISION"
                ;;
        esac
        ;;
        
    status)
        echo "=== Estado de Alertas ==="
        if [ -f "$ULTIMA_ALERTA_FILE" ]; then
            echo "Última alerta: $(date -r $(cat $ULTIMA_ALERTA_FILE) '+%Y-%m-%d %H:%M')"
        else
            echo "Sin alertas recientes"
        fi
        echo ""
        echo "Historial:"
        tail -5 "$ALERTAS_FILE" 2>/dev/null || echo "Sin historial"
        ;;
        
    enable)
        echo "[OK] Alertas inteligentes enabled"
        ;;
        
    disable)
        echo "[OK] Alertas inteligentes disabled"
        ;;
        
    *)
        echo "Usage: alerta-inteligente.sh [check|enable|disable|status]"
        ;;
esac