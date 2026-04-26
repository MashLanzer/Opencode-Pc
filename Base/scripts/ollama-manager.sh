#!/usr/bin/env bash
# Ollama Manager — Arrancar, mantener y descargar modelos
# Usage: ./ollama-manager.sh [modelo]

export PATH="$HOME/.local/bin:$PATH"
export OLLAMA_HOST="http://127.0.0.1:11434"

# 1. Asegurar servidor
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "[INFO] Iniciando Ollama..."
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

# 2. Verificar si el modelo ya está cargado
MODELO="${1:-llama3.2:1b}"
if curl -s http://127.0.0.1:11434/api/ps | grep -q "$MODELO"; then
    echo "[OK] Modelo $MODELO ya cargado en memoria"
    exit 0
fi

# 3. Si no está cargado, verificar si existe localmente
if curl -s http://127.0.0.1:11434/api/tags | grep -q "$MODELO"; then
    echo "[INFO] Modelo $MODELO existe, cargando..."
    curl -s http://127.0.0.1:11434/api/generate -d "{\"model\": \"$MODELO\", \"prompt\": \"hello\"}" > /dev/null
    echo "[OK] Modelo $MODELO cargado"
else
    echo "[INFO] Descargando modelo: $MODELO"
    /home/mash/.local/bin/ollama pull "$MODELO"
fi

echo "[OK] Listo"