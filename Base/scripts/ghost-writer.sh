#!/usr/bin/env bash
# Ghost Writer — Auto-documentación de proyectos
# Usage: ghost-writer.sh [proyecto]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
DRAFT_DIR="$AI_ROOT/Notas/drafts"
mkdir -p "$DRAFT_DIR"

PROYECTO="${1:-}"

# Buscar cambios recientes en archivos del proyecto
CAMBIOS=$(git -C "$AI_ROOT" diff --stat 2>/dev/null || echo "No hay cambios git detectados")

PROMPT="Eres un Ghost Writer técnico. Resume estos cambios en un documento técnico:
$CAMBIOS

Escribe una breve actualización para el proyecto $PROYECTO en formato Markdown."

RESPUESTA=$(/home/mash/Opencode/Base/scripts/ia-chat-engine.sh "$PROMPT")

# Guardar draft
FECHA=$(date '+%Y%m%d')
RUTA="$DRAFT_DIR/Doc_$PROYECTO_$FECHA.md"
echo "# Documentación automática: $PROYECTO" > "$RUTA"
echo "" >> "$RUTA"
echo "$RESPUESTA" >> "$RUTA"

echo "[OK] Borrador generado en $RUTA"