#!/usr/bin/env bash
# Memory Agent — Decide qué guardar en memoria
# Usage: memory-agent.sh "texto a analizar"

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"
LOG_FILE="/home/mash/Opencode/Base/logs/memory-agent.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

trap 'log "[ERROR] Fallo en Memory Agent"' ERR

# Asegurar que Ollama esté corriendo
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log "[INFO] Iniciando Ollama..."
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

CONTENIDO="${1:-}"

if [ -z "$CONTENIDO" ]; then
    log "[ERROR] Uso incorrecto: memory-agent.sh \"texto a analizar\""
    exit 1
fi

log "[INFO] Analizando con Memory Agent..."

# Prompt
PROMPT="Eres un Memory Agent. Analiza y decide donde guardar.

Estructura existente:
- Sistema/ (perfil, software, discos)
- Proyectos/ (proyectos activos)
- Conocimiento/ (notas generales)
- nota-rapida.md (ideas rapidas)
- tareas-pendientes.md (tareas)

Responde SOLO con una palabra: sistema, proyectos, conocimiento, nota-rapida, o tareas.

Informacion nueva: $CONTENIDO"

# Payload JSON
JSON_FILE=$(mktemp)
python3 -c "
import json
import sys
payload = {
    'model': '$MODEL',
    'prompt': sys.argv[1],
    'stream': False
}
print(json.dumps(payload))
" "$PROMPT" > "$JSON_FILE"

# Llamar a Ollama
RESPUESTA=$(curl -s http://127.0.0.1:11434/api/generate -d "@$JSON_FILE" | jq -r '.response' 2>/dev/null || echo "")
rm -f "$JSON_FILE"

# Categorizar
CATEGORIA=$(echo "$RESPUESTA" | tr '[:upper:]' '[:lower:]' | tr -d ' .' | grep -oE "sistema|proyectos|conocimiento|nota-rapida|tareas" | head -1)

# Default
[ -z "$CATEGORIA" ] && CATEGORIA="nota-rapida"

# Guardar
RUTA="$AI_ROOT/$CATEGORIA.md"
[ "$CATEGORIA" = "sistema" ] && RUTA="$AI_ROOT/Sistema/errores-y-soluciones.md"
[ "$CATEGORIA" = "proyectos" ] && RUTA="$AI_ROOT/Proyectos/_indice-proyectos.md"
[ "$CATEGORIA" = "conocimiento" ] && RUTA="$AI_ROOT/Conocimiento/notas-generales.md"

echo "" >> "$RUTA"
echo "### $(date '+%Y-%m-%d %H:%M')" >> "$RUTA"
echo "$CONTENIDO" >> "$RUTA"
log "[OK] Guardado en $CATEGORIA ($RUTA)"

echo "=== Decision: $CATEGORIA ==="