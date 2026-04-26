#!/usr/bin/env bash
set -euo pipefail

DATE_FMT=$(date '+%Y-%m-%d %H:%M')
AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
LOG_FILE="/home/mash/Opencode/Base/logs/actualizar-memoria.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

trap 'log "[ERROR] Fallo en la actualización de memoria"' ERR

log "=== Actualizando Memoria IA ==="

if [ ! -d "$AI_ROOT" ]; then
    log "[ERROR] AI-Memory no existe"
    exit 1
fi

MEMORIA_FILE="$AI_ROOT/MEMORIA-PRINCIPAL.md"
if [ -f "$MEMORIA_FILE" ]; then
    sed -i "s/Última sesión: .*/Última sesión: $DATE_FMT/" "$MEMORIA_FILE"
    log "[OK] MEMORIA-PRINCIPAL.md actualizada"
fi

# Actualizar otros archivos relevantes
for file in "$AI_ROOT/Sistema/perfil-sistema.md" "$AI_ROOT/Sistema/discos-y-particiones.md" "$AI_ROOT/Sistema/preferencias-usuario.md" "$AI_ROOT/Sistema/errores-y-soluciones.md" "$AI_ROOT/Sistema/comandos-utiles.md" "$AI_ROOT/Proyectos/_indice-proyectos.md" "$AI_ROOT/Conversaciones/_resumen-general.md" "$AI_ROOT/Conocimiento/plantilla-general.md" "$AI_ROOT/Notas/nota_"*".md" ; do
    [ -f "$file" ] || continue
    sed -i "s/Actualizado: .*/Actualizado: $DATE_FMT/" "$file" 2>/dev/null || true
done

log "=== Memoria actualizada exitosamente ==="
exit 0