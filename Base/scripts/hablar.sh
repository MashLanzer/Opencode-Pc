#!/usr/bin/env bash
# Voice Manager — Maneja la voz de la IA (Usa Edge TTS en entorno virtual)
# Usage: hablar.sh "texto"

set -euo pipefail

TEXTO="${1:-}"
[ -z "$TEXTO" ] && exit 0

VENV_PATH="/home/mash/Opencode/Base/venv"

# Si edge-tts existe en venv, usarlo (voz neural natural)
if [ -f "$VENV_PATH/bin/edge-tts" ] && command -v mpv &> /dev/null; then
    TEMP_AUDIO=$(mktemp /tmp/tts_XXXXXX.mp3)
    "$VENV_PATH/bin/edge-tts" --text "$TEXTO" --voice es-ES-AlvaroNeural --write-media "$TEMP_AUDIO" >/dev/null 2>&1
    mpv --no-video "$TEMP_AUDIO" >/dev/null 2>&1
    rm -f "$TEMP_AUDIO"
# Fallback a espeak-ng si no hay neural
elif command -v espeak-ng &> /dev/null; then
    espeak-ng -s 140 -v es-la "$TEXTO" &
else
    # Fallback visual
    notify-send "IA Companion" "$TEXTO" 2>/dev/null || echo "[VOZ] $TEXTO"
fi