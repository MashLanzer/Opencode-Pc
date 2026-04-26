#!/usr/bin/env bash
# IA CLI — Comando unificado para agentes
# Usage: ia [analyze|summary|memory|nota|categorize|task|run|start|stop|status|monitor|cron|experiment|restart|alert|session|api|metacognicion|mantenimiento|tui|help]

BASE_DIR="/home/mash/Opencode/Base/scripts"
PY_DIR="/home/mash/Opencode/Base/python"

case "${1:-help}" in
    analyze|a)
        shift
        "$BASE_DIR/analizar-notas.sh" "$@"
        ;;
    summary|s)
        "$BASE_DIR/resumen-sesion.sh"
        ;;
    memory|m)
        shift
        "$BASE_DIR/memory-agent.sh" "$@"
        ;;
    nota|n)
        shift
        "$BASE_DIR/nueva-nota.sh" "$@"
        ;;
    categorize|cat)
        shift
        "$BASE_DIR/categorizar-nota.sh" "$@"
        ;;
    task|t)
        shift
        "$BASE_DIR/task-runner.sh" "$@"
        ;;
    run|r)
        "$BASE_DIR/auto-agente.sh" run-once
        ;;
    start)
        "$BASE_DIR/auto-agente.sh" start
        "$BASE_DIR/monitor-sistema.sh" start
        "$BASE_DIR/auto-restart.sh" start
        ;;
    stop)
        "$BASE_DIR/auto-agente.sh" stop
        "$BASE_DIR/monitor-sistema.sh" stop
        "$BASE_DIR/auto-restart.sh" stop
        ;;
    status)
        "$BASE_DIR/auto-agente.sh" status
        "$BASE_DIR/monitor-sistema.sh" status
        "$BASE_DIR/auto-restart.sh" status
        ;;
    monitor|mon)
        shift
        "$BASE_DIR/monitor-sistema.sh" "$@"
        ;;
    cron|c)
        shift
        "$BASE_DIR/cron-inteligente.sh" "$@"
        ;;
    experiment|exp)
        shift
        "$BASE_DIR/auto-experiments.sh" "$@"
        ;;
    restart)
        shift
        "$BASE_DIR/auto-restart.sh" "$@"
        ;;
    alert)
        shift
        "$BASE_DIR/alerta-inteligente.sh" "$@"
        ;;
    session|ses)
        shift
        "$BASE_DIR/session-tracker.sh" "$@"
        ;;
        
    check-tasks|tasks)
        "$BASE_DIR/check-tasks.sh"
        ;;
        
    meta)
        "$BASE_DIR/metacognicion.sh"
        ;;
    meta)
        "$BASE_DIR/metacognicion.sh"
        ;;
    maint)
        "$BASE_DIR/mantenimiento-agente.sh"
        ;;
    tui)
        "$BASE_DIR/ia-tui.sh"
        ;;
    rag)
        shift
        case "${1:-}" in
            index|indexar)
                python3 "$PY_DIR/indexador.py" index
                ;;
            search|buscar)
                shift
                python3 "$PY_DIR/buscador.py" "$@"
                ;;
            status)
                python3 "$PY_DIR/indexador.py" status
                ;;
            serve)
                python3 "$PY_DIR/rag-api.py" 5001 &
                ;;
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
        echo "Comandos: analyze, summary, memory, nota, categorize, task, start, stop, status, monitor, cron, experiment, restart, alert, session, meta, maint, tui, rag, api"
        ;;
esac