#!/usr/bin/env bash
# Agente Nocturno — corre a las 3am, genera reporte de turno para el despertar
# Instalación: crontab -e → 0 3 * * * /home/mash/Opencode/Base/scripts/agente-nocturno.sh

BASE_DIR="/home/mash/Opencode/Base/scripts"
PY_DIR="/home/mash/Opencode/Base/python"
MEMORY_DIR="/home/mash/Opencode/Obsidian/AI-Memory"
VEXA_LOG="/home/mash/Opencode/VEXA/logs/vexa.log"
LOG_FILE="/home/mash/Opencode/Base/logs/agente-nocturno.log"
REPORT_FILE="$MEMORY_DIR/Sistema/reporte-nocturno.md"
NOTIFY_FLAG="/tmp/vexa-morning-report.flag"

TODAY=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

log() { echo "$TIMESTAMP - $1" | tee -a "$LOG_FILE"; }

log "=== Agente nocturno iniciado ==="

# ── 1. Estado del sistema ──────────────────────────────────────────────
DISK_USE=$(df -h / | awk 'NR==2{print $5}')
RAM_USE=$(free -h | awk '/^Mem/{print $3"/"$2}')
UPTIME=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //')

# ── 2. Análisis de logs VEXA ───────────────────────────────────────────
VEXA_ERRORS=0
VEXA_SESSIONS=0
if [ -f "$VEXA_LOG" ]; then
    VEXA_ERRORS=$(grep -c "\[ERROR\]\|\[WARNING\]" "$VEXA_LOG" 2>/dev/null || echo 0)
    VEXA_SESSIONS=$(grep -c "=== VEXA iniciando ===" "$VEXA_LOG" 2>/dev/null || echo 0)
fi

# ── 3. Git status del proyecto ────────────────────────────────────────
cd /home/mash/Opencode
GIT_STATUS=$(git status --short 2>/dev/null | wc -l)
GIT_LOG=$(git log --oneline -5 2>/dev/null || echo "sin commits recientes")

# ── 4. Diagnóstico rápido del sistema ─────────────────────────────────
DOCTOR_OUT=""
if [ -x "$BASE_DIR/ia-doctor.sh" ]; then
    DOCTOR_OUT=$("$BASE_DIR/ia-doctor.sh" 2>/dev/null | tail -10)
fi

# ── 5. Re-indexar RAG ─────────────────────────────────────────────────
RAG_OUT=""
if python3 "$PY_DIR/indexador.py" check 2>/dev/null | grep -q "re-index"; then
    log "[RAG] Re-indexando..."
    RAG_OUT=$(python3 "$PY_DIR/indexador.py" index 2>&1 | tail -3)
fi

# ── 6. Generar análisis con Ollama ────────────────────────────────────
ANALYSIS=""
if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    CONTEXT="Sistema: disco $DISK_USE, RAM $RAM_USE. VEXA: $VEXA_SESSIONS sesiones, $VEXA_ERRORS warnings/errors. Git: $GIT_STATUS archivos modificados."
    ANALYSIS=$(curl -s -X POST http://127.0.0.1:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"llama3.2:1b\",\"prompt\":\"Analiza brevemente este estado del sistema de Mash y da 1-2 sugerencias concretas para la mañana. Responde en español, máximo 3 líneas: $CONTEXT\",\"stream\":false}" \
        2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null)
fi

# ── 7. Escribir reporte en Obsidian ───────────────────────────────────
cat > "$REPORT_FILE" << REPORT
# Reporte Nocturno — $TODAY

> Generado automáticamente a las $TIMESTAMP

## Estado del Sistema
| Métrica | Valor |
|---------|-------|
| Disco / | $DISK_USE |
| RAM usada | $RAM_USE |
| Uptime | $UPTIME |
| VEXA sesiones ayer | $VEXA_SESSIONS |
| VEXA warnings | $VEXA_ERRORS |
| Archivos git pendientes | $GIT_STATUS |

## Últimos commits
\`\`\`
$GIT_LOG
\`\`\`

## Análisis IA
$ANALYSIS

## Doctor output
\`\`\`
$DOCTOR_OUT
\`\`\`

## RAG
$( [ -n "$RAG_OUT" ] && echo "$RAG_OUT" || echo "Índice al día, no requirió re-indexado." )

---
REPORT

log "Reporte guardado en $REPORT_FILE"

# ── 8. Dejar flag para notify-send al despertar ───────────────────────
echo "$TODAY" > "$NOTIFY_FLAG"

log "=== Agente nocturno completado ==="
