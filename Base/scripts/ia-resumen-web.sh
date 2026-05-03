#!/usr/bin/env bash
# IA Resumen Web — Descarga y resume el contenido de una URL
# Usage: ia-resumen-web.sh <url> [idioma]

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

MODEL="llama3.2:1b"
BASE_DIR="/home/mash/Opencode/Base/scripts"
hablar() { "$BASE_DIR/hablar.sh" "$1" 2>/dev/null || echo "[VOZ] $1"; }

URL="${1:-}"
LANG="${2:-español}"

if [ -z "$URL" ]; then
    echo "Uso: ia-resumen-web.sh <url> [idioma]"
    echo "Ejemplo: ia-resumen-web.sh https://example.com español"
    exit 1
fi

echo "[INFO] Descargando $URL ..."

# Extraer texto plano: HTML → texto limpio
TEXTO=$(curl -sL --max-time 30 --user-agent "Mozilla/5.0" "$URL" \
    | sed 's/<script[^>]*>.*<\/script>//gI' \
    | sed 's/<style[^>]*>.*<\/style>//gI' \
    | sed 's/<[^>]*>//g' \
    | sed '/^[[:space:]]*$/d' \
    | head -300)

if [ -z "$TEXTO" ]; then
    echo "[ERROR] No se pudo obtener contenido de $URL"
    exit 1
fi

CHARS=$(echo "$TEXTO" | wc -c)
echo "[INFO] ${CHARS} caracteres extraídos. Consultando IA..."

PROMPT="Resume el siguiente contenido web en $LANG. Sé conciso y claro. Máximo 150 palabras.

Contenido:
$TEXTO"

RESUMEN=$(curl -s http://127.0.0.1:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'stream':False}))" "$PROMPT")" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null)

if [ -z "$RESUMEN" ]; then
    echo "[ERROR] Ollama no respondió"
    exit 1
fi

echo ""
echo "=== Resumen de: $URL ==="
echo "$RESUMEN"
echo ""

# Hablar solo las primeras 2 oraciones
PRIMERAS=$(echo "$RESUMEN" | grep -oP '[^.!?]+[.!?]' | head -2 | tr '\n' ' ')
[ -n "$PRIMERAS" ] && hablar "$PRIMERAS"

# Guardar resumen
LOG_DIR="/home/mash/Opencode/Base/logs"
mkdir -p "$LOG_DIR"
echo "$(date '+%Y-%m-%d %H:%M') | $URL" >> "$LOG_DIR/resumenes-web.log"
echo "$RESUMEN" >> "$LOG_DIR/resumenes-web.log"
echo "---" >> "$LOG_DIR/resumenes-web.log"
