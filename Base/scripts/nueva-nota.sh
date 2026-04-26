#!/usr/bin/env bash
# Nueva Nota — Crea una nota en /home/mash/Opencode/Obsidian/AI-Memory/Notas/
# Usage: nueva-nota.sh "título" "contenido"

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory/Notas"
mkdir -p "$AI_ROOT"

TITULO="${1:-nota_sin_titulo}"
shift
CONTENIDO="$*"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUTA="$AI_ROOT/nota_$TIMESTAMP.md"
NOMBRE_ARCHIVO="nota_$TIMESTAMP"

# Crear el archivo
echo "# $TITULO" > "$RUTA"
echo "" >> "$RUTA"
echo "### $(date '+%Y-%m-%d %H:%M')" >> "$RUTA"
echo "$CONTENIDO" >> "$RUTA"

# Enlazar al índice
echo "" >> "$RUTA"
echo "---" >> "$RUTA"
echo "[[_index|Regresar al índice]]" >> "$RUTA"

# Actualizar índice
INDEX="$AI_ROOT/_index.md"
if [ ! -f "$INDEX" ]; then
    echo "# Índice de Notas" > "$INDEX"
    echo "" >> "$INDEX"
fi
echo "- [[$NOMBRE_ARCHIVO|$TITULO]]" >> "$INDEX"

echo "[OK] Nota creada: $RUTA"
echo "[OK] Enlazada en $INDEX"