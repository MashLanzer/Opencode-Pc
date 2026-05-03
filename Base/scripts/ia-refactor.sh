#!/usr/bin/env bash
# IA Refactor — Sugerencias de refactorización de código via Ollama
# Usage: ia-refactor.sh <archivo>
#        ia-refactor.sh <archivo> --apply   (reemplaza el archivo con la versión mejorada)

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

MODEL="llama3.2:1b"

ARCHIVO="${1:-}"
APPLY=0
[ "${2:-}" = "--apply" ] && APPLY=1

if [ -z "$ARCHIVO" ] || [ ! -f "$ARCHIVO" ]; then
    echo "Uso: ia-refactor.sh <archivo> [--apply]"
    echo "Ejemplo: ia-refactor.sh mi-script.py"
    echo "         ia-refactor.sh mi-script.py --apply"
    exit 1
fi

EXT="${ARCHIVO##*.}"
CONTENIDO=$(head -200 "$ARCHIVO")
LINEAS=$(wc -l < "$ARCHIVO")
NOMBRE=$(basename "$ARCHIVO")

echo "[INFO] Analizando $NOMBRE ($LINEAS líneas) ..."

PROMPT="Analiza el siguiente código en $EXT y sugiere mejoras de refactorización.
Sé específico y conciso. Máximo 200 palabras.
Incluye: problemas encontrados, sugerencias concretas, y código mejorado si aplica.
Responde en español.

Archivo: $NOMBRE
\`\`\`$EXT
$CONTENIDO
\`\`\`"

echo "Consultando Ollama..."

SUGERENCIAS=$(curl -s http://127.0.0.1:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'stream':False}))" "$PROMPT")" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null)

if [ -z "$SUGERENCIAS" ]; then
    echo "[ERROR] Ollama no respondió"
    exit 1
fi

echo ""
echo "=== Sugerencias para $NOMBRE ==="
echo "$SUGERENCIAS"
echo ""

# Si --apply: generar versión refactorizada y reemplazar
if [ "$APPLY" -eq 1 ]; then
    PROMPT2="Reescribe el siguiente código $EXT aplicando las mejoras de refactorización.
Devuelve SOLO el código, sin explicaciones, sin markdown, sin bloques de código.

$CONTENIDO"

    echo "Generando versión refactorizada..."

    NUEVO=$(curl -s http://127.0.0.1:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'stream':False}))" "$PROMPT2")" \
        | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null)

    if [ -n "$NUEVO" ]; then
        # Backup del original
        cp "$ARCHIVO" "${ARCHIVO}.bak"
        echo "$NUEVO" > "$ARCHIVO"
        echo "[OK] Archivo reemplazado (backup en ${ARCHIVO}.bak)"
    else
        echo "[WARN] No se pudo generar la versión refactorizada"
    fi
fi

# Guardar sugerencias
LOG_DIR="/home/mash/Opencode/Base/logs"
mkdir -p "$LOG_DIR"
{
    echo "## $(date '+%Y-%m-%d %H:%M') | $NOMBRE"
    echo "$SUGERENCIAS"
    echo ""
} >> "$LOG_DIR/refactor.log"
