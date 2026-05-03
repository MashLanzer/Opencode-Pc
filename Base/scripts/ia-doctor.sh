#!/usr/bin/env bash
# IA Doctor — Diagnóstico completo del sistema IA
# Usage: ia-doctor.sh [fix]

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

BASE_DIR="/home/mash/Opencode/Base/scripts"
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
LOGS_DIR="/home/mash/Opencode/Base/logs"
CONFIG_DIR="/home/mash/Opencode/Base/config"

OK=0; WARN=0; ERR=0
FIX="${1:-}"

ok()   { echo "  [OK]  $1"; OK=$((OK+1)); }
warn() { echo "  [--]  $1"; WARN=$((WARN+1)); }
err()  { echo "  [ERR] $1"; ERR=$((ERR+1)); }

echo ""
echo "=== IA Doctor — $(date '+%Y-%m-%d %H:%M') ==="
echo ""

# ── 1. Scripts del sistema ──────────────────────────────────────────
echo "Scripts:"
SCRIPTS=(
    ia.sh auto-agente.sh monitor-sistema.sh auto-restart.sh
    task-runner.sh janitor.sh inbox-agente.sh actualizar-memoria-ia.sh
    hablar.sh ia-chat-engine.sh ia-listen.sh session-tracker.sh
    ia-doctor.sh ia-census.sh ia-diario.sh ia-pomodoro.sh
    claude-hook-stop.sh
)
for s in "${SCRIPTS[@]}"; do
    if [ -f "$BASE_DIR/$s" ] && [ -x "$BASE_DIR/$s" ]; then
        ok "$s"
    elif [ -f "$BASE_DIR/$s" ]; then
        warn "$s (existe pero no es ejecutable)"
        [ "$FIX" = "fix" ] && chmod +x "$BASE_DIR/$s" && echo "       → Permisos corregidos"
    else
        err "$s (no encontrado)"
    fi
done

# ── 2. Archivos de memoria ──────────────────────────────────────────
echo ""
echo "Memoria:"
ARCHIVOS=(
    "MEMORIA-PRINCIPAL.md"
    "tareas-pendientes.md"
    "revision-diaria.md"
    "Sistema/preferencias-usuario.md"
    "Sistema/errores-y-soluciones.md"
    "Sistema/perfil-sistema.md"
    "Sistema/discos-y-particiones.md"
    "Sistema/software-instalado.md"
)
for f in "${ARCHIVOS[@]}"; do
    if [ -f "$AI_ROOT/$f" ] && [ -s "$AI_ROOT/$f" ]; then
        ok "$f"
    elif [ -f "$AI_ROOT/$f" ]; then
        warn "$f (existe pero está vacío)"
    else
        err "$f (no encontrado)"
        [ "$FIX" = "fix" ] && touch "$AI_ROOT/$f" && echo "       → Creado vacío"
    fi
done

# ── 3. Directorios necesarios ───────────────────────────────────────
echo ""
echo "Directorios:"
DIRS=(
    "$AI_ROOT/Sistema"
    "$AI_ROOT/Conversaciones"
    "$AI_ROOT/Proyectos"
    "$AI_ROOT/Conocimiento"
    "$AI_ROOT/Inbox"
    "$LOGS_DIR"
    "$CONFIG_DIR"
)
for d in "${DIRS[@]}"; do
    if [ -d "$d" ]; then
        ok "$(basename "$d")"
    else
        err "$(basename "$d") ($d)"
        [ "$FIX" = "fix" ] && mkdir -p "$d" && echo "       → Creado"
    fi
done

# ── 4. Servicios corriendo ──────────────────────────────────────────
echo ""
echo "Servicios:"
for pid_file in /tmp/auto-agente.pid /tmp/monitor-sistema.pid /tmp/auto-restart.pid; do
    nombre=$(basename "$pid_file" .pid)
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        ok "$nombre (PID: $(cat "$pid_file"))"
    else
        warn "$nombre no está corriendo"
    fi
done

if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    ok "Ollama (puerto 11434)"
else
    warn "Ollama no responde en 11434"
fi

# ── 5. Config y secretos ────────────────────────────────────────────
echo ""
echo "Configuración:"
if [ -f "$CONFIG_DIR/secrets" ] && [ -s "$CONFIG_DIR/secrets" ]; then
    ok "secrets (permisos: $(stat -c '%a' "$CONFIG_DIR/secrets"))"
else
    err "secrets no encontrado — ia-chat-engine no funcionará"
fi

if [ -f "$CONFIG_DIR/mode.conf" ]; then
    ok "mode.conf (modo: $(cat "$CONFIG_DIR/mode.conf"))"
else
    warn "mode.conf no encontrado"
    [ "$FIX" = "fix" ] && echo "normal" > "$CONFIG_DIR/mode.conf"
fi

# ── 6. Tareas del task-runner ───────────────────────────────────────
echo ""
echo "Tasks:"
TASKS_DIR="/home/mash/Opencode/Base/.tasks"
if [ -d "$TASKS_DIR" ]; then
    TOTAL=$(ls "$TASKS_DIR"/*.task 2>/dev/null | wc -l)
    echo "  [--]  $TOTAL task(s) registradas"
    # Verificar que los comandos referenciados existen
    for t in "$TASKS_DIR"/*.task; do
        [ -f "$t" ] || continue
        CMD=$(python3 -c "import json; d=json.load(open('$t')); print(d.get('comando',''))" 2>/dev/null || echo "")
        SCRIPT=$(echo "$CMD" | awk '{print $1}')
        if [ -n "$SCRIPT" ] && [[ "$SCRIPT" == /* ]] && [ ! -f "$SCRIPT" ]; then
            NOMBRE=$(python3 -c "import json; d=json.load(open('$t')); print(d.get('descripcion','?'))" 2>/dev/null)
            err "Task '$NOMBRE' → comando no existe: $SCRIPT"
        fi
    done
else
    warn "Carpeta .tasks no encontrada"
fi

# ── Resumen ─────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────"
echo "  OK: $OK   Avisos: $WARN   Errores: $ERR"
echo "─────────────────────────────────────"

if [ "$ERR" -gt 0 ] || [ "$WARN" -gt 2 ]; then
    echo "  Ejecuta 'ia doctor fix' para reparar automáticamente lo posible."
    "$BASE_DIR/hablar.sh" "Doctor: $ERR errores y $WARN avisos detectados." 2>/dev/null || true
else
    echo "  Sistema saludable."
    "$BASE_DIR/hablar.sh" "Sistema saludable, todo en orden." 2>/dev/null || true
fi
echo ""
