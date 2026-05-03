#!/usr/bin/env bash
# IA Listen — Captura audio, re-muestreo con ffmpeg, transcribe con Whisper
# Usage: ia-listen.sh

set -euo pipefail

VENV="/home/mash/Opencode/Base/venv"
WAV_RAW="/tmp/input_raw.wav"
WAV_CLEAN="/tmp/input.wav"
TXT_FILE="/tmp/input.txt"

# 1. Grabar audio (48kHz)
arecord -D hw:3,0 -f S16_LE -r 48000 -c 1 -d 3 "$WAV_RAW" >/dev/null 2>&1 || true

# 2. Resamplear a 16kHz (lo que Whisper necesita)
ffmpeg -i "$WAV_RAW" -ar 16000 -ac 1 -y "$WAV_CLEAN" >/dev/null 2>&1 || true

# 3. Transcribir con Whisper (Modelo 'base')
"$VENV/bin/whisper" "$WAV_CLEAN" --model base --language es --output_format txt --output_dir /tmp/ > /dev/null 2>&1 || true

# 4. Leer resultado
cat "${WAV_CLEAN%.*}.txt" 2>/dev/null | sed 's/^[0-9: ]*//' | tr -d '\n' || echo ""
rm -f "$WAV_RAW" "$WAV_CLEAN" "${WAV_CLEAN%.*}.txt" "${WAV_CLEAN%.*}.vtt" "${WAV_CLEAN%.*}.srt"