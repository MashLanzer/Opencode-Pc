#!/usr/bin/env bash
# Resumen automático de sesión — IA genera resumen de lo hecho
# Usage: resumen-sesion.sh

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"

# Asegurar que Ollama esté corriendo
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

FECHA=$(date '+%Y-%m-%d %H:%M')
DIA=$(date '+%Y-%m-%d')

# Leer info relevante
TAREAS=$(cat "$AI_ROOT/tareas-pendientes.md" 2>/dev/null | head -20)
NOTA_RAPIDA=$(cat "$AI_ROOT/nota-rapida.md" 2>/dev/null | head -20)

PROMPT="Resumen de sesión en 3 oraciones basado en:

Tareas pendientes:
$TAREAS

Notas rápidas:
$NOTA_RAPIDA

Fecha: $FECHA"

echo "[INFO] Generando resumen..."

RESPUESTA=$(echo "$PROMPT" | timeout 120 /home/mash/.local/bin/ollama run "$MODEL" 2>/dev/null)

# Guardar en resumen
RESUMEN_FILE="$AI_ROOT/Conversaciones/_resumen-general.md"
echo "### $DIA" >> "$RESUMEN_FILE"
echo "**Resumen IA:** $RESPUESTA" >> "$RESUMEN_FILE"
echo "" >> "$RESUMEN_FILE"

echo "=== Resumen guardado ==="
echo "$RESPUESTA"