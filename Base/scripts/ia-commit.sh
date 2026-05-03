#!/usr/bin/env bash
# IA Commit — Genera mensajes de commit con IA basados en el diff staged
# Usage: ia-commit.sh [--stage-all]

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

MODEL="llama3.2:1b"

if [ "${1:-}" = "--stage-all" ]; then
    git add -A
    echo "[OK] Todos los cambios staged"
fi

if git diff --cached --quiet; then
    echo "[WARN] No hay cambios staged. Usa: ia commit --stage-all"
    exit 0
fi

STAT=$(git diff --cached --stat | tail -1)
DIFF=$(git diff --cached -- '*.py' '*.sh' '*.js' '*.md' '*.json' | head -150)

PROMPT="Genera un mensaje de commit git conciso en español para estos cambios.
La primera línea debe ser máximo 70 caracteres con formato: tipo: descripcion
Tipos: feat, fix, docs, refactor, chore, style, test

Resumen de cambios: $STAT

Diff:
$DIFF

Responde SOLO con el mensaje de commit. Nada más."

echo "Consultando Ollama..."

MSG=$(curl -s http://127.0.0.1:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
prompt = sys.argv[1]
print(json.dumps({'model': 'llama3.2:1b', 'prompt': prompt, 'stream': False}))
" "$PROMPT")" | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null)

if [ -z "$MSG" ]; then
    echo "[ERROR] Ollama no respondió. ¿Está corriendo?"
    exit 1
fi

# Quedarse solo con la primera línea si Ollama dio demasiado texto
PRIMERA=$(echo "$MSG" | head -1)
RESTO=$(echo "$MSG" | tail -n +2)

echo ""
echo "══════════════════════════════════════"
echo "  Mensaje sugerido:"
echo "  $PRIMERA"
[ -n "$RESTO" ] && echo "  $RESTO"
echo "══════════════════════════════════════"
echo ""
read -rp "  [s] Confirmar  [e] Editar  [N] Cancelar: " OPT

case "${OPT,,}" in
    s)
        git commit -m "$MSG"
        echo "[OK] Commit creado: $PRIMERA"
        ;;
    e)
        EDITED=$(echo "$MSG" | "${EDITOR:-nano}")
        if [ -n "$EDITED" ]; then
            git commit -m "$EDITED"
            echo "[OK] Commit creado (editado)"
        fi
        ;;
    *)
        echo "[INFO] Cancelado"
        ;;
esac
