#!/usr/bin/env bash
HOY=$(date '+%Y-%m-%d')
TASKS_FILE="/home/mash/Opencode/Obsidian/AI-Memory/tareas-pendientes.md"

if [ -f "$TASKS_FILE" ]; then
    PENDIENTES=$(grep "\[ \]" "$TASKS_FILE" | grep "$HOY")
    if [ -n "$PENDIENTES" ]; then
        notify-send "📅 Tareas para hoy" "$PENDIENTES" 2>/dev/null || echo "[INFO] Tareas para hoy: $PENDIENTES"
    fi
fi
