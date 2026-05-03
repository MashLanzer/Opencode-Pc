#!/usr/bin/env bash
# IA Recordatorio — Recordatorios por voz o texto con timer
# Usage:
#   ia-recordatorio.sh "en 30 minutos llama a fulano"
#   ia-recordatorio.sh list
#   ia-recordatorio.sh clear

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

BASE_DIR="/home/mash/Opencode/Base/scripts"
LOG_FILE="/home/mash/Opencode/Base/logs/recordatorios.txt"

hablar() { "$BASE_DIR/hablar.sh" "$1" 2>/dev/null || echo "[VOZ] $1"; }

mkdir -p "$(dirname "$LOG_FILE")"

case "${1:-}" in
    list)
        if [ -s "$LOG_FILE" ]; then
            echo "=== Recordatorios activos ==="
            cat "$LOG_FILE"
        else
            echo "[INFO] Sin recordatorios activos"
        fi
        exit 0
        ;;
    clear)
        rm -f "$LOG_FILE"
        echo "[OK] Recordatorios borrados"
        exit 0
        ;;
esac

TEXTO="${*}"
if [ -z "$TEXTO" ]; then
    echo "Uso: ia-recordatorio.sh \"en 30 minutos <qué recordar>\""
    exit 1
fi

# Intentar parsear con regex primero (rápido, sin Ollama)
MINUTOS=0
MENSAJE="$TEXTO"

if echo "$TEXTO" | grep -qiE "en ([0-9]+) minuto"; then
    MINUTOS=$(echo "$TEXTO" | grep -oiE "[0-9]+ minuto" | grep -oE "[0-9]+")
    MENSAJE=$(echo "$TEXTO" | sed -E 's/en [0-9]+ minutos?[, ]*//' | sed 's/^[ ,]*//')
elif echo "$TEXTO" | grep -qiE "en ([0-9]+) hora"; then
    H=$(echo "$TEXTO" | grep -oiE "[0-9]+ hora" | grep -oE "[0-9]+")
    MINUTOS=$((H * 60))
    MENSAJE=$(echo "$TEXTO" | sed -E 's/en [0-9]+ horas?[, ]*//' | sed 's/^[ ,]*//')
fi

# Si regex no capturó, usar Ollama
if [ "$MINUTOS" -eq 0 ]; then
    echo "Analizando con IA..."
    PROMPT="Extrae el tiempo en minutos y el mensaje de este recordatorio.
Responde SOLO JSON válido: {\"minutos\": 30, \"mensaje\": \"llamar a fulano\"}
Texto: $TEXTO"

    RESULTADO=$(curl -s http://127.0.0.1:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "$(python3 -c "import json,sys; print(json.dumps({'model':'llama3.2:1b','prompt':sys.argv[1],'stream':False}))" "$PROMPT")" \
        | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null)

    MINUTOS=$(echo "$RESULTADO" | python3 -c "
import json,sys,re
text = sys.stdin.read()
# Extraer el primer JSON válido del texto
m = re.search(r'\{[^}]+\}', text)
if m:
    try:
        d = json.loads(m.group())
        print(int(d.get('minutos', 0)))
    except:
        print(0)
else:
    print(0)
" 2>/dev/null || echo "0")

    MENSAJE=$(echo "$RESULTADO" | python3 -c "
import json,sys,re
text = sys.stdin.read()
m = re.search(r'\{[^}]+\}', text)
if m:
    try:
        d = json.loads(m.group())
        print(d.get('mensaje',''))
    except:
        print('')
else:
    print('')
" 2>/dev/null || echo "")

    [ -z "$MENSAJE" ] && MENSAJE="$TEXTO"
fi

if [ "$MINUTOS" -le 0 ]; then
    echo "[ERROR] No pude detectar el tiempo. Ejemplo: 'en 20 minutos llamar a fulano'"
    exit 1
fi

HORA_DISPARO=$(date -d "+${MINUTOS} minutes" '+%H:%M')
echo "[OK] Recordatorio a las $HORA_DISPARO: $MENSAJE"
hablar "Entendido. Te recuerdo '$MENSAJE' en $MINUTOS minutos."

# Guardar en log
echo "$(date -d "+${MINUTOS} minutes" '+%Y-%m-%d %H:%M') | $MENSAJE" >> "$LOG_FILE"

# Timer en background
(
    sleep $((MINUTOS * 60))
    hablar "Recordatorio: $MENSAJE"
    notify-send "⏰ VEXA" "$MENSAJE" -u critical 2>/dev/null || true
    # Remover del log
    grep -v "| $MENSAJE" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null || true
) &
disown

echo "[OK] Timer activo (dispara a las $HORA_DISPARO)"
