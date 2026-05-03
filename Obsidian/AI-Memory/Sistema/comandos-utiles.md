# ⌨️ Comandos Útiles

> Actualizado: 2026-04-27 19:58

## Sistema
```bash
# Ver salud de discos
sudo smartctl -a /dev/sda

# Reparar sistema de archivos
fsck /dev/sdXN -y

# Ver particiones con UUIDs
blkid

# Montar todos los discos de fstab
sudo mount -a
```

## Personalización
```bash
# Aplicar tema GTK
gsettings set org.cinnamon.desktop.interface gtk-theme "NOMBRE"

# Reiniciar Cinnamon sin cerrar sesión
cinnamon --replace &

# Ver tema actual
gsettings get org.cinnamon.desktop.interface gtk-theme
```

## Procesos
```bash
# Matar y reiniciar Conky
pkill conky; conky -d

# Matar y reiniciar Plank
pkill plank; plank &
```