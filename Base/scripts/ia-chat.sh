#!/usr/bin/env bash
# IA Chat — Conversación interactiva por voz (Versión 2.0 - Interactiva)
# Usage: ia-chat.sh

set -euo pipefail

echo "=== Conversación iniciada. Di 'adiós' para salir. ==="
/home/mash/Opencode/Base/scripts/hablar.sh "Iniciando modo conversación. ¿En qué puedo ayudarte hoy, Mash?"

while true; do
    echo "[Escuchando...]"
    
# 1. Escuchar y transcribir
    TXT=$(/home/mash/Opencode/Base/scripts/ia-listen.sh || echo "")
    
    # Si la transcripción está vacía, saltar
    [ -z "$TXT" ] && continue
    
    echo "Tú: $TXT"
    
    # 2. Procesar con el motor (Chat Engine)
    RESP=$(/home/mash/Opencode/Base/scripts/ia-chat-engine.sh "$TXT" || echo "No pude procesar eso.")
    echo "IA: $RESP"
    
    # 3. Hablar
    /home/mash/Opencode/Base/scripts/hablar.sh "$RESP" || true
    
    # 4. Salir si el usuario dice adiós
    if [[ "${TXT,,}" =~ "adiós" || "${TXT,,}" =~ "salir" ]]; then
        /home/mash/Opencode/Base/scripts/hablar.sh "Hasta luego, Mash."
        break
    fi
done