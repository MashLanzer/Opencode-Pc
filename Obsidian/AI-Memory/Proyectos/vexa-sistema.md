# VEXA — Sistema de Voz IA Personal

> Estado: 🟢 Operativo + Daemon
> Última actualización: 2026-04-27
> Ubicación del código: `/home/mash/Opencode/VEXA/`

---

## ¿Qué es VEXA?

VEXA es un sistema operativo conversacional local. Escucha la voz de Mash en español, procesa comandos con Ollama (IA local), muestra una interfaz web animada con una esfera de partículas, y responde con voz sintetizada.

No es un chatbot. Es una IA con estado, animada y multimodal que vive en la PC.

---

## Stack Técnico

| Capa | Tecnología |
|------|-----------|
| Backend | Python 3.14 + asyncio (stdlib) |
| WebSocket | `websockets` 15.0 |
| Voz entrada (STT) | Whisper (`Base/venv`) + arecord + ffmpeg |
| Voz salida (TTS) | edge-tts (`Base/venv`) + mpv |
| LLM | Ollama local — llama3.2:1b (puerto 11434) |
| API externa | OpenRouter (`Base/config/secrets`) |
| PC Control | Claude Code CLI como subproceso |
| UI | HTML/CSS/JS — esfera de partículas animada |
| GPU | AMD Radeon RX 580 — **NO CUDA** → ROCm/CPU |

---

## Cómo Iniciar

```bash
# Via CLI unificado (recomendado)
ia vexa start              # con micrófono
ia vexa start --no-voice   # solo API + UI
ia vexa stop
ia vexa status
ia vexa logs               # tail en tiempo real
ia vexa ui                 # abrir panel web

# Directamente
./VEXA/run.sh [--no-voice] [--no-ui] [--no-wake]
```

La interfaz web se abre en: **http://localhost:8765**

---

## Módulos

| Módulo | Función |
|--------|---------|
| `vexa_core.py` | Orquestador principal, loop de voz, pipeline de intents, re-detect device cada 5 fallos |
| `state_manager.py` | Máquina de 6 estados con suscriptores async |
| `ollama_client.py` | Cliente HTTP a Ollama, historial de conversación |
| `voice_input.py` | Grabación (arecord) + transcripción (Whisper). Prioriza USB sobre integrado. `refresh_device()` |
| `voice_output.py` | TTS edge-tts neural + fallback espeak-ng |
| `command_library.py` | Detección de intents por regex en español |
| `opencode_bridge.py` | Claude Code CLI como subproceso persistente |
| `ui_server.py` | HTTP REST en :8765 + WebSocket en :8766 |
| `ui/` | Esfera de partículas + input de texto para enviar comandos sin voz |
| `memory_search.py` | RAG sobre vault Obsidian — contexto de memoria en respuestas de Ollama |
| `wake_word.py` | Detecta "oye VEXA" y variantes (beka, weka, etc.) |

---

## Estados del Sistema

| Estado | Visual | Cuándo |
|--------|--------|--------|
| IDLE | Esfera azul, reposo | Esperando |
| LISTENING | Verde, ondas de entrada | Grabando voz |
| THINKING | Naranja, caótico | Procesando con Ollama |
| SPEAKING | Violeta, ondas salientes | Reproduciendo TTS |
| PC_CONTROL | Azul intenso, overlay terminal | Control de PC con Claude Code |
| AGENT | Naranja/rojo | Tareas autónomas |

---

## API REST (localhost:8765)

```bash
GET  /status                          # Estado actual
POST /speak   {"text": "hola"}        # VEXA habla algo
POST /state   {"state": "THINKING"}   # Cambiar estado
POST /command {"command": "modo pc"}  # Enviar comando
GET  /log                             # Últimos eventos
```

## WebSocket (ws://localhost:8766)

```json
// Recibir (eventos del sistema)
{"type": "state_change", "state": "LISTENING"}
{"type": "log", "level": "info", "message": "..."}

// Enviar (comandos del cliente)
{"type": "ping"}
{"type": "get_status"}
```

---

## Comandos de Voz Reconocidos

| Comando | Acción |
|---------|--------|
| "modo pc" / "modo terminal" | Activa control de PC via Claude Code |
| "modo agente" | Activa modo agente autónomo |
| "modo chat" / "modo normal" | Vuelve al chat con Ollama |
| "para" / "stop" / "silencio" | Interrumpe acción actual |
| "cómo estás" / "estado" | Reporta estado del sistema |
| "limpia el historial" | Borra contexto de conversación |
| "ayuda" | Lista comandos disponibles |
| "adiós" / "hasta luego" | Apaga VEXA |

---

## Dispositivo de Audio

```
Dispositivo activo : hw:3,0 — USB MIC-E01 (score 2 — USB dedicado)
Auto-detección     : sí, prioridad USB-dedicado > USB-cámara > integrado
Re-detección       : automática cada 5 fallos consecutivos

Todos los dispositivos:
- hw:0,0 — ALC897 Analog (integrada placa madre) — score 0
- hw:1,0 — FHD Camera Microphone (USB cámara)   — score 1
- hw:3,0 — USB MIC-E01 (micrófono dedicado)      — score 2 ← activo
```

---

## Bugs Resueltos

| Fecha | Bug | Solución |
|-------|-----|----------|
| 2026-04-26 | `_ws_clients` UnboundLocalError en broadcast | Cambió `_ws_clients -= dead` → `.difference_update()` |
| 2026-04-26 | arecord `hw:3,0` no existe, spin loop | Auto-detección de dispositivo + backoff exponencial en fallo |
| 2026-04-27 | `detect_audio_device()` elegía `hw:0,0` (Intel HDA) — bucle infinito de errores | Scoring USB: usb-dedicado=2, usb-cámara=1, integrado=0. Selecciona `hw:3,0` |
| 2026-04-27 | RAG search siempre devolvía lista vacía | `memory_search.py` ahora detecta estructura anidada `{"documentos":{...}}` del índice |

---

## Integración con el sistema (2026-04-27 — Sesión 2)

### Arranque automático
```bash
ia vexa enable    # Activa autoarranque con tu sesión de usuario
ia vexa disable   # Desactiva
```
VEXA corre como **systemd user service** — arranca con el login, se reinicia si cae.

### Atajo de teclado
| Atajo | Acción |
|-------|--------|
| **Super+V** | Abre la UI de VEXA. Si no está corriendo, la inicia. |

### Notificaciones de escritorio
VEXA usa `notify-send` para:
- Confirmar que arrancó
- Avisar del reporte nocturno al despertar

### Agente nocturno (3am)
Corre solo mientras dormís. Genera `Sistema/reporte-nocturno.md` con:
- Estado del disco/RAM
- Errores de VEXA del día
- Últimos commits del proyecto
- Análisis con Ollama + sugerencias

### Accesos rápidos
| Cómo | Resultado |
|------|-----------|
| `Super+V` | Abre VEXA UI |
| Buscador de apps → "VEXA" | Inicia + abre UI |
| `ia vexa start` | Terminal |
| Wake word "oye VEXA" | Hablar directamente |

---

## Mejoras Implementadas (2026-04-27 — Sesión 1)

- [x] `voice_input.py` — scoring de dispositivos USB, método `refresh_device()`
- [x] `vexa_core.py` — re-detección automática de micrófono cada 5 fallos
- [x] `memory_search.py` — parser RAG corregido, limpieza de markdown en búsqueda
- [x] `Base/python/indexador.py` — limpieza de markdown + stopwords al indexar, `needs_reindex()`, `check` subcommand
- [x] `VEXA/ui/` — input de texto en HUD para enviar comandos sin voz (Enter o botón ↵)
- [x] `Base/scripts/vexa-manager.sh` — gestión completa del proceso VEXA vía CLI
- [x] `Base/scripts/ia.sh` — `ia vexa [start|stop|status|restart|ui|logs]` integrado
- [x] `Base/scripts/auto-agente.sh` — auto-indexado RAG al detectar archivos nuevos

---

## Mejoras Implementadas (2026-04-27 — Sesión 2)

- [x] `ollama_client.py` — `chat_stream()` generator token a token + `embedding()`
- [x] `voice_output.py` — `speak_sentences()`: TTS solapado con generación (latencia ~1s vs ~4s)
- [x] `vexa_core.py` — pipeline de streaming activado, notify-send al arrancar, reporte matutino
- [x] `memory_search.py` — búsqueda híbrida: keyword + coseno semántico via Ollama embeddings
- [x] `Base/python/indexador.py` — genera embeddings Ollama durante indexado
- [x] `~/.config/systemd/user/vexa.service` — daemon con autoarranque y auto-restart
- [x] `Base/scripts/vexa-manager.sh` — integrado con systemd + notify-send
- [x] `Base/scripts/vexa-toggle.sh` — script del atajo Super+V
- [x] Atajo **Super+V** registrado en Cinnamon vía dconf
- [x] `.desktop` en aplicaciones del sistema (`ia` + icono SVG)
- [x] `Base/scripts/agente-nocturno.sh` — análisis nocturno 3am con reporte Obsidian
- [x] Cron 3am instalado para agente nocturno

## Próximas Mejoras

- [ ] Modo texto permanente (`--text`) para usar stdin sin micrófono ni Whisper
- [ ] TTS fallback automático si edge-tts falla (sin internet)
- [ ] Panel de historial de conversación en la UI
- [ ] Conky widget con estado VEXA en escritorio
