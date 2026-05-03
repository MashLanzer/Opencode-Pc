#!/usr/bin/env bash
# IA Standup — Daily standup desde git log + historial de sesiones + tareas
# Usage: ia-standup.sh [--speak]

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

MODEL="llama3.2:1b"
BASE_DIR="/home/mash/Opencode/Base/scripts"
MEMORY_DIR="/home/mash/Opencode/Obsidian/AI-Memory"
LOG_DIR="/home/mash/Opencode/Base/logs"
hablar() { "$BASE_DIR/hablar.sh" "$1" 2>/dev/null || echo "[VOZ] $1"; }

SPEAK=0
[ "${1:-}" = "--speak" ] && SPEAK=1

echo "=== Generando standup diario ==="

# 1. Git log de las últimas 24h
GIT_LOG=""
if git -C /home/mash/Opencode log --oneline --since="24 hours ago" 2>/dev/null | head -20 | read -r; then
    GIT_LOG=$(git -C /home/mash/Opencode log --oneline --since="24 hours ago" 2>/dev/null | head -20)
fi

# 2. Sesiones recientes
SESSION_HIST=""
if [ -f "$LOG_DIR/session-history.md" ]; then
    SESSION_HIST=$(tail -30 "$LOG_DIR/session-history.md")
elif [ -f "$MEMORY_DIR/Conversaciones/_resumen-general.md" ]; then
    SESSION_HIST=$(tail -30 "$MEMORY_DIR/Conversaciones/_resumen-general.md")
fi

# 3. Tareas completadas hoy
TAREAS_HOY=""
HOY=$(date '+%Y-%m-%d')
if [ -f "$MEMORY_DIR/tareas-pendientes.md" ]; then
    TAREAS_HOY=$(grep -A2 "\[$HOY\]\|DONE\|✓\|completad" "$MEMORY_DIR/tareas-pendientes.md" 2>/dev/null | head -20)
fi

# 4. Diario de hoy
DIARIO_HOY=""
if [ -f "$MEMORY_DIR/revision-diaria.md" ]; then
    DIARIO_HOY=$(grep -A10 "^## $HOY\|^### $HOY" "$MEMORY_DIR/revision-diaria.md" 2>/dev/null | head -20)
fi

# Construir contexto
CONTEXTO=""
[ -n "$GIT_LOG"      ] && CONTEXTO+="COMMITS GIT (últimas 24h):\n$GIT_LOG\n\n"
[ -n "$SESSION_HIST" ] && CONTEXTO+="SESIONES RECIENTES:\n$SESSION_HIST\n\n"
[ -n "$TAREAS_HOY"   ] && CONTEXTO+="TAREAS:\n$TAREAS_HOY\n\n"
[ -n "$DIARIO_HOY"   ] && CONTEXTO+="DIARIO DE HOY:\n$DIARIO_HOY\n\n"

if [ -z "$CONTEXTO" ]; then
    echo "[WARN] Sin datos suficientes para el standup"
    echo "Hoy es $(date '+%A %d de %B'). No hay actividad registrada."
    exit 0
fi

FECHA=$(date '+%A %d de %B de %Y')

PROMPT="Genera un standup diario profesional en español para Brian (Mash) basado en los siguientes datos.
Formato: 3 secciones — QUÉ HICE AYER, QUÉ HARÉ HOY, BLOQUEOS/NOTAS.
Fecha: $FECHA
Sé conciso, usa viñetas, máximo 120 palabras en total.

$CONTEXTO"

echo "Consultando IA..."

STANDUP=$(curl -s http://127.0.0.1:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'stream':False}))" "$PROMPT")" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null)

if [ -z "$STANDUP" ]; then
    echo "[ERROR] Ollama no respondió"
    exit 1
fi

echo ""
echo "=== STANDUP — $FECHA ==="
echo "$STANDUP"
echo ""

# Guardar
mkdir -p "$LOG_DIR"
{
    echo "## Standup $FECHA"
    echo "$STANDUP"
    echo ""
} >> "$LOG_DIR/standups.md"

echo "[OK] Guardado en $LOG_DIR/standups.md"

# Hablar si se pidió
if [ "$SPEAK" -eq 1 ]; then
    PRIMER_BLOQUE=$(echo "$STANDUP" | head -6 | tr '\n' ' ')
    hablar "$PRIMER_BLOQUE"
fi
