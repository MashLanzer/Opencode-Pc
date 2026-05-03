#!/usr/bin/env bash
# IA CLI — Comando unificado para agentes
# Usage: ia [analyze|summary|memory|nota|categorize|task|run|start|stop|status|monitor|cron|experiment|restart|alert|session|api|rag|meta|maint|tui|janitor|inbox|creative|help]

BASE_DIR="/home/mash/Opencode/Base/scripts"
PY_DIR="/home/mash/Opencode/Base/python"

case "${1:-help}" in
    analyze|a) "$BASE_DIR/analizar-notas.sh" "${@:2}" ;;
    summary|s) "$BASE_DIR/resumen-sesion.sh" ;;
    memory|m) "$BASE_DIR/memory-agent.sh" "${@:2}" ;;
    nota|n) "$BASE_DIR/nueva-nota.sh" "${@:2}" ;;
    categorize|cat) "$BASE_DIR/categorizar-nota.sh" "${@:2}" ;;
    task|t) "$BASE_DIR/task-runner.sh" "${@:2}" ;;
    creative|cr) "$BASE_DIR/agente-creativo.sh" "${@:2}" ;;
    run|r) "$BASE_DIR/auto-agente.sh" run-once ;;
    start)
        "$BASE_DIR/auto-agente.sh" start
        "$BASE_DIR/monitor-sistema.sh" start
        "$BASE_DIR/auto-restart.sh" start
        "$BASE_DIR/vexa-manager.sh" start --no-voice
        ;;
    stop)
        "$BASE_DIR/auto-agente.sh" stop
        "$BASE_DIR/monitor-sistema.sh" stop
        "$BASE_DIR/auto-restart.sh" stop
        "$BASE_DIR/vexa-manager.sh" stop
        ;;
    status)
        "$BASE_DIR/auto-agente.sh" status
        "$BASE_DIR/monitor-sistema.sh" status
        "$BASE_DIR/auto-restart.sh" status
        "$BASE_DIR/vexa-manager.sh" status
        ;;
    monitor|mon) "$BASE_DIR/monitor-sistema.sh" "${@:2}" ;;
    cron|c) "$BASE_DIR/cron-inteligente.sh" "${@:2}" ;;
    experiment|exp) "$BASE_DIR/auto-experiments.sh" "${@:2}" ;;
    restart) "$BASE_DIR/auto-restart.sh" "${@:2}" ;;
    alert) "$BASE_DIR/alerta-inteligente.sh" "${@:2}" ;;
    session|ses) "$BASE_DIR/session-tracker.sh" "${@:2}" ;;
    meta) "$BASE_DIR/metacognicion.sh" ;;
    maint) "$BASE_DIR/mantenimiento-agente.sh" ;;
    tui) "$BASE_DIR/ia-tui.sh" ;;
    janitor) "$BASE_DIR/janitor.sh" ;;
    inbox) "$BASE_DIR/inbox-agente.sh" ;;
    doctor) "$BASE_DIR/ia-doctor.sh" "${@:2}" ;;
    census) "$BASE_DIR/ia-census.sh" ;;
    diario) "$BASE_DIR/ia-diario.sh" "${@:2}" ;;
    pomo) "$BASE_DIR/ia-pomodoro.sh" "${@:2}" ;;
    commit) "$BASE_DIR/ia-commit.sh" "${@:2}" ;;
    recordatorio|rec) "$BASE_DIR/ia-recordatorio.sh" "${@:2}" ;;
    web|resumen-web) "$BASE_DIR/ia-resumen-web.sh" "${@:2}" ;;
    standup|stand) "$BASE_DIR/ia-standup.sh" "${@:2}" ;;
    traducir|tr) "$BASE_DIR/ia-traductor.sh" "${@:2}" ;;
    refactor|ref) "$BASE_DIR/ia-refactor.sh" "${@:2}" ;;
    vexa) "$BASE_DIR/vexa-manager.sh" "${@:2}" ;;
    rag)
        shift
        case "${1:-}" in
            index) python3 "$PY_DIR/indexador.py" index ;;
            search) python3 "$PY_DIR/buscador.py" "${@:2}" ;;
            status) python3 "$PY_DIR/indexador.py" status ;;
        esac
        ;;
    api)
        shift
        case "${1:-status}" in
            start) python3 "$PY_DIR/api-memoria.py" & ;;
            *) python3 "$PY_DIR/api-memoria.py" ;;
        esac
        ;;
    help|*)
        echo "=== IA CLI ==="
        echo "Comandos: analyze, summary, memory, nota, categorize, task, creative, start, stop, status,"
        echo "          monitor, cron, experiment, restart, alert, session, meta, maint, tui, rag, api,"
        echo "          janitor, inbox, doctor, census, diario, pomo, commit, recordatorio,"
        echo "          web <url>, standup, traducir [--idioma <lang>] <texto>, refactor <archivo>"
        echo ""
        echo "VEXA:     vexa start [--no-voice]   — iniciar sistema de voz"
        echo "          vexa stop                  — detener"
        echo "          vexa status                — estado del proceso"
        echo "          vexa restart               — reiniciar"
        echo "          vexa enable                — autoarranque con el login"
        echo "          vexa disable               — quitar autoarranque"
        echo "          vexa ui                    — abrir panel web"
        echo "          vexa logs                  — tail del log en tiempo real"
        ;;
esac