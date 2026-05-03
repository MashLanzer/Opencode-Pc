#!/usr/bin/env bash
# IA Traductor — Traduce texto via Ollama
# Usage: ia-traductor.sh [--idioma <lang>] <texto>
#        ia-traductor.sh --idioma ingles "hola mundo"
#        ia-traductor.sh "hello world"   (auto-detecta y traduce al español)
#        ia-traductor.sh < archivo.txt

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

MODEL="llama3.2:1b"
BASE_DIR="/home/mash/Opencode/Base/scripts"
hablar() { "$BASE_DIR/hablar.sh" "$1" 2>/dev/null || echo "[VOZ] $1"; }

TARGET="español"
SPEAK=0

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --idioma|-i) TARGET="$2"; shift 2 ;;
        --speak|-s)  SPEAK=1; shift ;;
        *) break ;;
    esac
done

# Leer texto: argumento o stdin
if [ $# -gt 0 ]; then
    TEXTO="${*}"
elif [ ! -t 0 ]; then
    TEXTO=$(cat)
else
    echo "Uso: ia-traductor.sh [--idioma <lang>] <texto>"
    echo "     ia-traductor.sh --idioma ingles 'hola mundo'"
    echo "     echo 'hello' | ia-traductor.sh --idioma español"
    exit 1
fi

if [ -z "$TEXTO" ]; then
    echo "[ERROR] No hay texto para traducir"
    exit 1
fi

echo "[INFO] Traduciendo a $TARGET ..."

PROMPT="Traduce el siguiente texto al $TARGET. Responde SOLO con la traducción, sin explicaciones, sin comillas.

Texto: $TEXTO"

RESULTADO=$(curl -s http://127.0.0.1:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'stream':False}))" "$PROMPT")" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null)

if [ -z "$RESULTADO" ]; then
    echo "[ERROR] Ollama no respondió"
    exit 1
fi

echo ""
echo "[$TARGET] $RESULTADO"
echo ""

[ "$SPEAK" -eq 1 ] && hablar "$RESULTADO"
