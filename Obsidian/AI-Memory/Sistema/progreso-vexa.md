# VEXA — Esquema de Progreso

> Última actualización: 2026-04-27 (sesión 4)
> Estado general: 🟢 Sistema operativo, accesible desde PC y móvil

---

## Estado por capa

### Infraestructura

| Componente | Estado | Notas |
|-----------|--------|-------|
| `vexa_core.py` — orquestador | ✅ Completo | Pipeline streaming, memoria episódica, multimodal |
| `state_manager.py` — estados | ✅ Completo | 6 estados: IDLE/LISTENING/THINKING/SPEAKING/PC_CONTROL/AGENT |
| `systemd user service` | ✅ Activo | `vexa.service` + `vexa-hud.service` habilitados |
| Comando `ia` en terminal | ✅ Corregido | Symlink en `~/.local/bin/ia` + alias en `.bashrc` |
| Atajo `Super+V` | ✅ Registrado | dconf Cinnamon — abre UI o inicia VEXA |
| Icono `.desktop` | ✅ Instalado | Aparece en buscador de apps de Cinnamon |

### Voz

| Componente | Estado | Notas |
|-----------|--------|-------|
| STT (Whisper) | ✅ Completo | Modelo `base`, auto-detección USB |
| TTS (edge-tts) | ✅ Completo | Streaming por oraciones — latencia ~1s |
| Detección micrófono | ✅ Corregido | Scoring USB: hw:3,0 USB MIC-E01 |
| Wake word | ✅ Completo | "oye VEXA" + variantes (beka, weka, etc.) |
| TTS fallback | ⚠️ Pendiente | espeak-ng existe pero no auto-switch sin internet |

### Memoria / RAG

| Componente | Estado | Notas |
|-----------|--------|-------|
| Índice RAG keyword | ✅ Completo | 37+ docs, limpieza markdown, stopwords |
| Embeddings Ollama | ✅ Implementado | Coseno semántico via `/api/embeddings` |
| Búsqueda híbrida | ✅ Completo | keyword + semántico, merge con dedup |
| Auto-indexado | ✅ Activo | `auto-agente.sh` re-indexa si hay cambios |
| Memoria episódica | ✅ Nuevo | Todo lo que dice VEXA → `Conversaciones/YYYY-MM-DD.md` |
| Notas por voz | ✅ Nuevo | "guarda que..." → `nota-rapida.md` directo |

### UI / Acceso

| Componente | Estado | Notas |
|-----------|--------|-------|
| Web UI (esfera) | ✅ Completo | localhost:8765, input de texto incluido |
| HUD flotante | ✅ Nuevo | `hud.py` Tk, siempre visible, Super+V o ia vexa hud |
| REST API | ✅ Completo | GET /status, POST /command, /state, /speak |
| WebSocket | ✅ Completo | ws://localhost:8766 — eventos en tiempo real |

### Integración del sistema

| Componente | Estado | Notas |
|-----------|--------|-------|
| Arranque automático | ✅ Activo | systemd + `ia vexa enable` |
| Agente nocturno | ✅ Activo | Cron 3am — reporte en `Sistema/reporte-nocturno.md` |
| notify-send | ✅ Integrado | Al arrancar y al detectar reporte matutino |
| CLI `ia` unificado | ✅ Completo | `ia vexa [start|stop|status|enable|hud|logs...]` |

### Multimodal

| Componente | Estado | Notas |
|-----------|--------|-------|
| OCR pantalla | ✅ Mejorado | scrot (ventana activa) + tesseract spa+eng |
| Análisis streaming | ✅ Completo | Respuesta en streaming mientras procesa |
| Triggers de voz | ✅ Ampliado | "describí la pantalla", "qué dice ese error", etc. |
| Captura clipboard | ⚠️ Pendiente | xclip no instalado |
| Visión real (LLaVA) | 🔵 Futuro | Requiere modelo vision + ROCm setup |

### Acceso Móvil

| Componente | Estado | Notas |
|-----------|--------|-------|
| UI móvil (`mobile.html`) | ✅ Completo | Responsive, dark theme, PWA-ready |
| Web Speech API (STT) | ✅ Completo | Chrome Android hace STT nativo, envía texto a VEXA |
| Servidor en red local | ✅ Completo | `0.0.0.0` — accesible desde cualquier device en WiFi |
| URL acceso | ✅ | `http://192.168.5.81:8765/mobile.html` |
| Conversación en pantalla | ✅ | Historial de mensajes usuario/VEXA en el móvil |
| WS dinámico | ✅ | `window.location.hostname` — funciona desde PC y móvil |

### Resumen Matutino

| Componente | Estado | Notas |
|-----------|--------|-------|
| `_morning_briefing()` | ✅ Completo | Corre automáticamente al iniciar entre 5am-1pm |
| Tareas pendientes | ✅ | Cuenta `- [ ]` en tareas-pendientes.md |
| Resumen de ayer | ✅ | Lee conversaciones del día anterior |
| Reporte nocturno | ✅ | Integrado — detecta flag del agente 3am |
| Síntesis con Ollama | ✅ | Genera saludo natural de 2 oraciones |
| Notificación desktop | ✅ | notify-send con el resumen |

---

## Roadmap pendiente

### Implementado en Sesión 5

- [x] **Historial hablado** — "resumí la sesión de ayer/hoy/la semana" → Ollama resume en 3 puntos
- [x] **Modo profesor** — "explícame X" → explicación + guarda en `Conocimiento/X.md`
- [x] **Captura por voz** — "guarda esto" → scrot ventana activa → `Obsidian/Capturas/ts.png` + notify-send
- [x] **QR en HUD** — botón QR abre popup con código escaneable para acceso móvil
- [x] **qrcode** instalado en sistema

### Alta prioridad

- [ ] **TTS fallback automático** — si edge-tts falla (sin internet), cambiar a espeak-ng automáticamente
- [ ] **Panel historial conversación** en la UI web (desktop) — últimas N respuestas visibles
- [ ] **Personalidad contextual** — VEXA detecta ventana activa (Foundry, VS Code, Godot) y adapta su behavior
- [ ] **VEXA en Foundry VTT** — comandos de voz D&D via WebSocket de Foundry

### Media prioridad

- [ ] **Modo texto** — `ia vexa start --text` para usar sin micrófono
- [ ] **Modo escritura inmersiva** — silencia notifs, activa Pomodoro, solo responde preguntas creativas
- [ ] **Agregar QR code** al arranque de VEXA (muestra el QR de la URL móvil en el HUD)

### Baja prioridad / Futuro

- [ ] **LLaVA/visión real** — modelo vision + ROCm (AMD RX 580)
- [ ] **Sincronización cloud** — rclone + Mega/Proton para AI-Memory
- [ ] **Conky widget** — cuando se instale conky: status en escritorio siempre visible

---

## Sesiones de trabajo

| Sesión | Implementado |
|--------|-------------|
| Sesión 1 | Core VEXA (todos los módulos Python), UI web, wake word |
| Sesión 2 | Fix micrófono USB, fix RAG estructura, RAG mejorado (37 docs), input texto UI |
| Sesión 3 | Streaming TTS (~1s latencia), embeddings Ollama, systemd daemon, Super+V, HUD Tk, agente nocturno |
| Sesión 4 | Fix `ia` CLI, HUD flotante completo, memoria episódica, multimodal mejorado, UI móvil (Web Speech), resumen matutino |
| Sesión 5 | Historial hablado (resumí ayer), modo profesor (guarda en Conocimiento/), captura por voz, QR en HUD |

---

## Acceso rápido

```bash
# Primera vez — activar todo
source ~/.bashrc           # activar alias ia y vexa
ia vexa enable             # autoarranque con el login
ia vexa start              # iniciar ahora

# Uso diario (después del primer enable ya es automático)
Super+V                    # abrir UI desde cualquier lugar
ia vexa hud                # widget flotante en escritorio
ia vexa status             # ver si está corriendo
ia vexa logs               # log en tiempo real

# Desde el teléfono (misma WiFi)
http://192.168.5.81:8765/mobile.html
# → Chrome Android: toca el micrófono y habla
```

---

## Arquitectura actual

```
PC (Linux Mint Cinnamon)
│
├── systemd --user
│   ├── vexa.service    → python3 VEXA/vexa_core.py  (siempre activo)
│   └── vexa-hud.service → python3 VEXA/hud.py        (widget escritorio)
│
├── VEXA/
│   ├── vexa_core.py      — orquestador + memoria episódica
│   ├── voice_input.py    — STT Whisper, USB MIC-E01 auto-detect
│   ├── voice_output.py   — TTS streaming por oraciones
│   ├── ollama_client.py  — LLM streaming + embeddings
│   ├── memory_search.py  — RAG híbrido keyword+semántico
│   ├── hud.py            — widget Tk siempre visible
│   └── ui/               — web UI con input de texto
│
├── Base/
│   ├── scripts/ia.sh     — CLI unificado (`ia`)
│   └── scripts/agente-nocturno.sh  — cron 3am
│
└── Obsidian/AI-Memory/
    ├── Conversaciones/YYYY-MM-DD.md  — diario automático
    ├── nota-rapida.md                — notas por voz
    └── Sistema/reporte-nocturno.md  — reporte del agente
```
