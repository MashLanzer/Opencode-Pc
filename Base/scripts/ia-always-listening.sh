#!/usr/bin/env bash
# IA Always Listening — Escucha constante
# Usage: ia-always-listening.sh

set -euo pipefail
VENV="/home/mash/Opencode/Base/venv"

echo "[INFO] Sistema de escucha activa iniciado. Esperando palabra clave 'sistema'..."

while true; do
    # 1. Escuchar y detectar palabra clave
    TXT=$(/home/mash/Opencode/Base/scripts/ia-listen.sh)
    
    # 2. Si detecta "sistema", entra en modo chat
    if [[ "${TXT,,}" =~ "sistema" ]]; then
        /home/mash/Opencode/Base/scripts/hablar.sh "Dime, Mash."
        # Ejecutar chat interactivo
        /home/mash/Opencode/Base/scripts/ia-chat.sh
    fi
done