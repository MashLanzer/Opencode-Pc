#!/usr/bin/env bash
set -euo pipefail

# Backup AI-Memory to /home/mash/Opencode/Base/scripts/.ai-memory-backup/
# Usage: ./backup-memoria-ia.sh

DATE_DAY=$(date '+%Y-%m-%d')
BACKUP_DIR="$HOME/.ai-memory-backup"
SOURCE_DIR="/home/mash/Opencode/Obsidian/AI-Memory"

echo "=== Respaldo de Memoria IA ==="
echo "Fecha: $DATE_DAY"

# Crear directorio de backup si no existe
mkdir -p "$BACKUP_DIR"

# Nombre del archivo de backup
BACKUP_FILE="$BACKUP_DIR/ai-memory-$DATE_DAY.tar.gz"

# Crear backup
tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" AI-Memory/

echo "[OK] Backup creado: $BACKUP_FILE"

# Mantener solo los últimos 7 backups
cd "$BACKUP_DIR"
ls -t ai-memory-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

echo "[OK] Backups antiguos limpiados (se mantienen los últimos 7)"
echo ""
echo "=== Respaldo completado ==="