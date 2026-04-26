#!/usr/bin/env bash
# Auto-Experiments — Pruebas automáticas de código
# Usage: auto-experiments.sh [run|add|list|status|report]

set -euo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
DATA_DIR="$AI_ROOT/.experiments"
mkdir -p "$DATA_DIR"

COMMAND="${1:-list}"

case "$COMMAND" in
    add)
        NOMBRE="${2:-}"
        COMANDO="${3:-}"
        DESCRIPCION="${4:-}"
        
        if [ -z "$NOMBRE" ] || [ -z "$COMANDO" ]; then
            echo "Usage: auto-experiments.sh add \"nombre\" \"comando\" [descripcion]"
            exit 1
        fi
        
        ID=$(date +%s)
        echo "$NOMBRE|$COMANDO|$DESCRIPCION|pending|0|0" > "$DATA_DIR/exp_$ID.txt"
        echo "[OK] Experimento agregado: $NOMBRE"
        ;;
        
    list)
        echo "=== Experimentos ==="
        for f in "$DATA_DIR"/exp_*.txt; do
            [ -f "$f" ] || continue
            IFS='|' read -r nombre cmd desc status ok fail < "$f"
            echo "[$status] $nombre (OK: $ok, FAIL: $fail)"
            echo "    comando: $cmd"
        done
        ;;
        
    run)
        NOMBRE="${2:-}"
        
        if [ -n "$NOMBRE" ]; then
            # Buscar experimento específico
            for f in "$DATA_DIR"/exp_*.txt; do
                [ -f "$f" ] || continue
                IFS='|' read -r n cmd desc status ok fail < "$f"
                if [ "$n" = "$NOMBRE" ]; then
                    echo "[EJECUTANDO] $NOMBRE"
                    if eval "$cmd" >/tmp/exp_output.txt 2>&1; then
                        echo "    Resultado: OK"
                        old_ok=$ok
                        new_ok=$((old_ok + 1))
                        sed -i "s/$ok$/$new_ok/" "$f"
                        sed -i "s/pending/running/" "$f"
                        sleep 1
                        sed -i "s/running/done/" "$f"
                    else
                        echo "    Resultado: FAIL"
                        old_fail=$fail
                        new_fail=$((old_fail + 1))
                        sed -i "s/$old_fail$/$new_fail/" "$f"
                        sed -i "s/pending/running/" "$f"
                        sleep 1
                        sed -i "s/running/failed/" "$f"
                        echo "    Output:"
                        cat /tmp/exp_output.txt | head -5 | sed 's/^/    /'
                    fi
                    break
                fi
            done
        else
            # Ejecutar todos los pending
            for f in "$DATA_DIR"/exp_*.txt; do
                [ -f "$f" ] || continue
                IFS='|' read -r n cmd desc status ok fail < "$f"
                if [ "$status" = "pending" ]; then
                    echo "[EJECUTANDO] $n"
                    if eval "$cmd" >/tmp/exp_output.txt 2>&1; then
                        old_ok=$ok
                        new_ok=$((old_ok + 1))
                        sed -i "s/$ok$/$new_ok/" "$f"
                        sed -i "s/pending/done/" "$f"
                        echo "    OK"
                    else
                        old_fail=$fail
                        new_fail=$((old_fail + 1))
                        sed -i "s/$old_fail$/$new_fail/" "$f"
                        sed -i "s/pending/failed/" "$f"
                        echo "    FAIL"
                    fi
                fi
            done
        fi
        ;;
        
    report)
        echo "=== Reporte de Experimentos ==="
        TOTAL=0
        OK=0
        FAIL=0
        
        for f in "$DATA_DIR"/exp_*.txt; do
            [ -f "$f" ] || continue
            IFS='|' read -r nombre cmd desc status ok fail < "$f"
            TOTAL=$((TOTAL + 1))
            OK=$((OK + ok))
            FAIL=$((FAIL + fail))
        done
        
        echo "Total experimentos: $TOTAL"
        echo "Exitosos: $OK"
        echo "Fallidos: $FAIL"
        
        if [ $TOTAL -gt 0 ]; then
            echo "Éxito: $((OK * 100 / TOTAL))%"
        fi
        ;;
        
    status)
        PENDING=0
        RUNNING=0
        DONE=0
        FAILED=0
        
        for f in "$DATA_DIR"/exp_*.txt; do
            [ -f "$f" ] || continue
            IFS='|' read -r nombre cmd desc status ok fail < "$f"
            case "$status" in
                pending) PENDING=$((PENDING + 1)) ;;
                running) RUNNING=$((RUNNING + 1)) ;;
                done) DONE=$((DONE + 1)) ;;
                failed) FAILED=$((FAILED + 1)) ;;
            esac
        done
        
        echo "=== Estado ==="
        echo "Pendientes: $PENDING"
        echo "Corrriendo: $RUNNING"
        echo "Completados: $DONE"
        echo "Fallidos: $FAILED"
        ;;
        
    *)
        echo "Usage: auto-experiments.sh [add|list|run|status|report]"
        ;;
esac