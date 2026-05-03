#!/usr/bin/env bash
# VEXA — Script de inicio
# Uso: ./VEXA/run.sh [--no-voice] [--no-ui]

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Asegurar Ollama corriendo
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "[VEXA] Iniciando Ollama..."
    nohup ollama serve > /tmp/ollama-vexa.log 2>&1 &
    sleep 4
fi

echo "[VEXA] Iniciando sistema..."
cd "$SCRIPT_DIR"
exec python3 vexa_core.py "$@"
