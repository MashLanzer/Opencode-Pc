#!/usr/bin/env bash
# IA Census — Auto-llenado del perfil del sistema
# Usage: ia-census.sh

set -uo pipefail

AI_ROOT="/home/mash/Opencode/Obsidian/AI-Memory"
FECHA=$(date '+%Y-%m-%d %H:%M')

echo "=== IA Census — $FECHA ==="

# ── perfil-sistema.md ───────────────────────────────────────────────
PERFIL="$AI_ROOT/Sistema/perfil-sistema.md"
echo "Recopilando hardware..."

CPU=$(lscpu | awk -F': +' '/^Model name/{print $2; exit}')
NUCLEOS=$(nproc)
RAM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
GPU=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | sed 's/.*: //' || echo "No detectada")
HOSTNAME=$(hostname)
DISTRO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
SHELL_ACTIVO=$(basename "$SHELL")
UPTIME=$(uptime -p)

cat > "$PERFIL" << EOF
# Perfil del Sistema
> Actualizado: $FECHA

## Hardware

| Campo | Valor |
|-------|-------|
| Hostname | $HOSTNAME |
| CPU | $CPU |
| Núcleos | $NUCLEOS |
| RAM Total | $RAM_TOTAL |
| GPU | $GPU |

## Software Base

| Campo | Valor |
|-------|-------|
| Distro | $DISTRO |
| Kernel | $KERNEL |
| Shell | $SHELL_ACTIVO |
| Uptime | $UPTIME |
EOF

echo "  [OK] perfil-sistema.md actualizado"

# ── discos-y-particiones.md ─────────────────────────────────────────
DISCOS="$AI_ROOT/Sistema/discos-y-particiones.md"
echo "Recopilando discos..."

cat > "$DISCOS" << EOF
# Discos y Particiones
> Actualizado: $FECHA

## Uso actual (df -h)

\`\`\`
$(df -h --output=source,size,used,avail,pcent,target | grep -v tmpfs | grep -v udev)
\`\`\`

## Particiones (lsblk)

\`\`\`
$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v loop)
\`\`\`

## Salud de discos (smartctl)

\`\`\`
$(for disk in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'); do
    echo "--- $disk ---"
    smartctl -H "$disk" 2>/dev/null | grep -E "SMART|result" || echo "smartctl no disponible"
done)
\`\`\`
EOF

echo "  [OK] discos-y-particiones.md actualizado"

# ── software-instalado.md ───────────────────────────────────────────
SOFTWARE="$AI_ROOT/Sistema/software-instalado.md"
echo "Recopilando software..."

{
    echo "# Software Instalado"
    echo "> Actualizado: $FECHA"
    echo ""

    echo "## Apps principales (dpkg)"
    echo "\`\`\`"
    dpkg -l 2>/dev/null | awk '/^ii/{print $2, $3}' | grep -E \
        "python3|nodejs|git|curl|wget|vim|nvim|kitty|zsh|fish|ollama|ffmpeg|mpv|espeak|whisper|godot|obsidian|code|chromium|firefox" \
        | sort | head -40
    echo "\`\`\`"
    echo ""

    if command -v snap &>/dev/null; then
        echo "## Snap"
        echo "\`\`\`"
        snap list 2>/dev/null | tail -n +2 | awk '{print $1, $2}'
        echo "\`\`\`"
        echo ""
    fi

    if command -v flatpak &>/dev/null; then
        echo "## Flatpak"
        echo "\`\`\`"
        flatpak list --columns=name,version 2>/dev/null | head -20
        echo "\`\`\`"
        echo ""
    fi

    echo "## Python (pip)"
    echo "\`\`\`"
    pip3 list 2>/dev/null | grep -E "flask|fastapi|requests|numpy|pandas|whisper|openai|anthropic|rich|typer" | head -20
    echo "\`\`\`"
    echo ""

    echo "## Ollama — Modelos"
    echo "\`\`\`"
    curl -s http://127.0.0.1:11434/api/tags 2>/dev/null | python3 -c \
        "import json,sys; d=json.load(sys.stdin); [print(m['name']) for m in d.get('models',[])]" 2>/dev/null \
        || echo "Ollama no disponible"
    echo "\`\`\`"
} > "$SOFTWARE"

echo "  [OK] software-instalado.md actualizado"

echo ""
echo "Census completo. Archivos actualizados en Sistema/."
/home/mash/Opencode/Base/scripts/hablar.sh "Census completo. Perfil del sistema actualizado." 2>/dev/null || true
