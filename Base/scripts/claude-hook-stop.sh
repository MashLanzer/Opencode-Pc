#!/usr/bin/env bash
# Claude Hook Stop — Guarda resumen de sesión Claude Code en AI-Memory
# Llamado automáticamente por el hook Stop de Claude Code

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
CONV_DIR="$AI_ROOT/Conversaciones"
RESUMEN_GENERAL="$CONV_DIR/_resumen-general.md"
MODEL="llama3.2:1b"
FECHA=$(date '+%Y-%m-%d')
HORA=$(date '+%H:%M')
ARCHIVO_HOY="$CONV_DIR/$FECHA.md"

mkdir -p "$CONV_DIR"

# Leer el transcript de la sesión actual desde el stdin (Claude lo pasa via stdin)
TRANSCRIPT=$(cat 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    msgs = data.get('messages', [])
    lines = []
    for m in msgs[-20:]:
        role = m.get('role', '')
        content = m.get('content', '')
        if isinstance(content, list):
            content = ' '.join(p.get('text','') for p in content if isinstance(p,dict))
        if content:
            lines.append(f'{role}: {str(content)[:200]}')
    print('\n'.join(lines))
except:
    print('')
" 2>/dev/null || echo "")

# Si no hay transcript via stdin, usar git para detectar qué cambió en la sesión
if [ -z "$TRANSCRIPT" ]; then
    CAMBIOS=$(git -C /home/mash/Opencode diff --name-only HEAD 2>/dev/null | head -10 || echo "")
    GIT_STATUS=$(git -C /home/mash/Opencode status --short 2>/dev/null | head -10 || echo "")
    TRANSCRIPT="Archivos modificados en esta sesión:\n$CAMBIOS\n\nEstado git:\n$GIT_STATUS"
fi

# Generar resumen con Ollama
PROMPT="Eres un asistente que resume sesiones de trabajo con Claude Code.
Genera un resumen en español de máximo 5 líneas de lo que se trabajó en esta sesión.
Incluye: qué se hizo, qué decisiones se tomaron, qué archivos se modificaron.

Contexto de la sesión:
$TRANSCRIPT

Responde solo con el resumen, sin títulos ni listas."

RESUMEN=$(curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$(echo "$PROMPT" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" | tr -d '"')\", \"stream\": false}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null \
    || echo "Sesión de trabajo con Claude Code completada el $FECHA.")

# Añadir al archivo del día
{
    if [ ! -f "$ARCHIVO_HOY" ]; then
        echo "# Conversaciones Claude Code — $FECHA"
        echo ""
    fi
    echo "## Sesión $HORA"
    echo ""
    echo "$RESUMEN"
    echo ""
    echo "---"
    echo ""
} >> "$ARCHIVO_HOY"

# Actualizar _resumen-general.md con las últimas 5 sesiones
{
    echo "# Resumen General de Conversaciones"
    echo "> Actualizado: $FECHA $HORA"
    echo ""
    echo "## Últimas sesiones"
    echo ""
    # Listar los últimos 5 archivos de conversación
    find "$CONV_DIR" -name "*.md" ! -name "_*" | sort -r | head -5 | while read -r f; do
        FNAME=$(basename "$f" .md)
        PRIMER_RESUMEN=$(grep -A2 "## Sesión" "$f" | grep -v "^##\|^---\|^$" | head -1)
        echo "- **$FNAME**: $PRIMER_RESUMEN"
    done
} > "$RESUMEN_GENERAL"

echo "[Claude Hook] Sesión guardada en $ARCHIVO_HOY"
