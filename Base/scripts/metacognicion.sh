#!/usr/bin/env bash
# Agente de Metacognición — Analiza productividad y sugiere mejoras
# Usage: metacognicion.sh [analizar]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
MODEL="llama3.2:1b"
INSTRUCCIONES="$HOME/Opencode/INSTRUCCIONES-IA.md"
RESUMEN="$AI_ROOT/Conversaciones/_resumen-general.md"
REVISION="$AI_ROOT/revision-diaria.md"

# Asegurar Ollama
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    nohup /home/mash/.local/bin/ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
fi

echo "[INFO] Analizando historial para sugerir mejoras..."

# Leer archivos
HISTORIAL=$(cat "$RESUMEN" "$REVISION" 2>/dev/null | tail -50)
ACTUALES=$(cat "$INSTRUCCIONES")

PROMPT="Analiza el siguiente historial de trabajo:
$HISTORIAL

Y las instrucciones actuales de la IA:
$ACTUALES

Sugiere 3 mejoras concretas para INSTRUCCIONES-IA.md que aumenten la productividad o corrijan errores recurrentes observados en el historial. Responde solo con las 3 sugerencias en formato de lista."

# Llamar a Ollama
SUGERENCIAS=$(echo "$PROMPT" | timeout 120 /home/mash/.local/bin/ollama run "$MODEL" 2>/dev/null)

echo "=== Sugerencias de la IA ==="
echo "$SUGERENCIAS"

echo ""
read -p "¿Aplicar sugerencias a INSTRUCCIONES-IA.md? (s/n): " confirm
if [[ $confirm == [sS] ]]; then
    echo -e "\n## Mejoras sugeridas el $(date)\n$SUGERENCIAS" >> "$INSTRUCCIONES"
    echo "[OK] Instrucciones actualizadas."
fi