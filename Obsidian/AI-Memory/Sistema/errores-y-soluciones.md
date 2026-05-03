# 🔧 Errores y Soluciones

> Actualizado: 2026-04-27 19:58

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
### 2026-04-27 — VEXA: Micrófono USB no detectado (bucle de error)
**Error:** `arecord` falla en bucle con `hw:0,0` (ALC897 integrado), VEXA nunca escucha
**Causa:** `detect_audio_device()` retornaba el primer dispositivo de la lista (`hw:0,0` Intel HDA) en lugar del micrófono USB real (`hw:3,0` USB MIC-E01)
**Solución:** Reescribir `detect_audio_device()` en `VEXA/voice_input.py` con sistema de scoring: USB-dedicado (score 2) > USB-cámara (score 1) > integrado (score 0). Añadir `refresh_device()` que se llama cada 5 fallos consecutivos en `voice_loop`.
**Prevención:** Al conectar/desconectar micrófonos USB, VEXA ahora re-detecta automáticamente cada 5 intentos fallidos.

### 2026-04-27 — VEXA: Búsqueda RAG no devolvía resultados
**Error:** `MemorySearch.search()` siempre devolvía lista vacía aunque el índice existía
**Causa:** El índice RAG tiene estructura anidada `{"documentos": {doc_id: {...}}}` pero el parser lo leía como `{"documentos": {...}, "metadatos": {...}}` iterando sobre esas dos claves en lugar de los documentos reales
**Solución:** Detectar estructura en `_load()`: si existe clave `"documentos"`, usar `raw["documentos"]` como índice. También limpiar símbolos markdown en las palabras del índice antes de comparar.
**Prevención:** El índice RAG quedó funcional. Si se regenera el índice con otro formato, el parser ahora lo detecta automáticamente.
