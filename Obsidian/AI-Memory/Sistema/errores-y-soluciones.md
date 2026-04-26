# 🔧 Errores y Soluciones

> Actualizado: 2026-04-26 17:05

## Historial de errores

### 2026-04-25 — initramfs al arrancar Linux Mint
**Error:** Sistema cae en shell initramfs en lugar de arrancar
**Causa:** Corrupción del sistema de archivos en /dev/sda4
**Solución:** `fsck /dev/sda4 -y` desde el shell de initramfs, luego `exit`
**Prevención:** No apagar bruscamente. Revisar salud del disco con `smartctl -a /dev/sda`

## Plantilla para nuevos errores
<!--
### [FECHA] — Título del error
**Error:** descripción
**Causa:** por qué ocurrió
**Solución:** cómo se resolvió
**Prevención:** cómo evitarlo
-->
### 2026-04-26 14:48
Esta es una prueba de memoria
