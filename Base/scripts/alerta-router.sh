#!/usr/bin/env bash
# Alerta Router — Filtra alertas por severidad
# Usage: alerta-router.sh [CRÍTICO|INFO] "mensaje"

set -euo pipefail

SEVERIDAD="${1:-INFO}"
MENSAJE="${2:-}"
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
PENDIENTES="$AI_ROOT/alertas-pendientes.md"

if [ "$SEVERIDAD" = "CRÍTICO" ]; then
    notify-send -u critical "⚠️ ALERTA CRÍTICA" "$MENSAJE" 2>/dev/null || echo "[CRÍTICO] $MENSAJE"
else
    mkdir -p "$(dirname "$PENDIENTES")"
    echo "- [ ] $(date '+%Y-%m-%d %H:%M'): $MENSAJE" >> "$PENDIENTES"
    echo "[INFO] Alerta guardada en $PENDIENTES"
fi