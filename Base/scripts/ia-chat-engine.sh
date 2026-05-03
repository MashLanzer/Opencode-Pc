#!/usr/bin/env bash
# IA Chat Engine — Motor de conversación usando OpenRouter API
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

SECRETS_FILE="/home/mash/Opencode/Base/config/secrets"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: no se encontró $SECRETS_FILE" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$SECRETS_FILE"

HISTORIAL="/tmp/ia_chat_history.txt"
touch "$HISTORIAL"
CONTENIDO="$*"

PROMPT="Eres un asistente personal amigable. Responde a la pregunta del usuario de forma natural y breve.
Historial reciente:
$(tail -n 3 "$HISTORIAL")

Pregunta actual: $CONTENIDO"

PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'model': 'meta-llama/llama-3.1-8b-instruct', 'messages': [{'role': 'user', 'content': sys.argv[1]}]}))" "$PROMPT")

RESPUESTA=$(curl -s https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)

if [ -z "$RESPUESTA" ]; then
    RESPUESTA="Error de comunicación con IA."
fi

echo "Usuario: $CONTENIDO" >> "$HISTORIAL"
echo "IA: $RESPUESTA" >> "$HISTORIAL"

echo "$RESPUESTA"