#!/usr/bin/env bash
set -euo pipefail

# Track de sesiones IA
# Usage: ./track-sesion-ia.sh [proyecto] [descripcion]

DATE_FMT=$(date '+%Y-%m-%d %H:%M')
DATE_DAY=$(date '+%Y-%m-%d')
TRACK_FILE="/home/mash/Opencode/Obsidian/AI-Memory/track-sesiones.md"
PROYECTO="${1:-general}"
DESCRIPCION="${2:-sesión sin descripción}"

# Crear archivo si no existe
if [ ! -f "$TRACK_FILE" ]; then
    cat > "$TRACK_FILE" << 'EOF'
# 📊 Track de Sesiones

> Actualizado: 2026-04-26

## Sesiones por fecha

EOF
fi

# Agregar entrada
echo "### $DATE_DAY" >> "$TRACK_FILE"
echo "- **$PROYECTO:** $DESCRIPCION ($DATE_FMT)" >> "$TRACK_FILE"

echo "[OK] Sesión registrada: $PROYECTO - $DESCRIPCION"
echo "     Fecha: $DATE_FMT"