# VEXA en Windows — Guía de Instalación

## Qué es esto

Este es el sistema VEXA completo: IA de voz personal con memoria, interfaz web, y control del PC. Corre localmente, sin nube, sobre modelos Ollama.

---

## Requisitos previos (instalar una vez)

### 1. Python 3.11+
Descargar de https://python.org — marcar **"Add to PATH"** al instalar.

### 2. Ollama
Descargar de https://ollama.com/download — instalador Windows disponible.
Después de instalar, abrir terminal y correr:
```
ollama pull llama3.2:1b
```

### 3. Dependencias Python
Abrir PowerShell en la carpeta `Opencode/` y correr:
```powershell
pip install websockets edge-tts openai-whisper qrcode pillow
```

### 4. ffmpeg (para Whisper y audio)
Descargar de https://ffmpeg.org/download.html y agregar al PATH.

### 5. Para TTS (voz de VEXA)
`edge-tts` funciona directo en Windows. No necesita nada extra.

---

## Estructura de carpetas

```
Opencode/
├── VEXA/                  ← Sistema de IA de voz
│   ├── vexa_core.py       ← Arrancar esto para iniciar VEXA
│   ├── voice_input.py     ← Micrófono + Whisper STT
│   ├── voice_output.py    ← TTS con edge-tts
│   ├── ollama_client.py   ← Conexión a Ollama local
│   ├── memory_search.py   ← RAG sobre Obsidian vault
│   ├── hud.py             ← Widget flotante (requiere tkinter)
│   └── ui/                ← Web UI (index.html + mobile.html)
├── Base/
│   ├── scripts/           ← Scripts de automatización (bash → adaptar a .bat/.ps1)
│   └── python/            ← Indexador RAG, dashboard
└── Obsidian/AI-Memory/    ← Vault de memoria persistente
```

---

## Arrancar VEXA en Windows

### Opción A — PowerShell simple
```powershell
cd Opencode
python VEXA\vexa_core.py
```
Después abrir en el browser: http://localhost:8765

### Opción B — Sin micrófono (solo web/texto)
```powershell
python VEXA\vexa_core.py --no-voice
```

### Opción C — Crear acceso directo
Crear un archivo `iniciar-vexa.bat` en `Opencode/`:
```bat
@echo off
start "" python VEXA\vexa_core.py
timeout /t 4
start http://localhost:8765
```

---

## Ajustes necesarios para Windows

### 1. Micrófono (voice_input.py)
En Linux usa `arecord`. En Windows hay que cambiar a `sounddevice` o `pyaudio`.

Editar `VEXA/voice_input.py` — reemplazar el bloque `arecord` por:
```python
import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wav

def record_audio(filename, duration=5, samplerate=16000):
    audio = sd.rec(int(duration * samplerate), samplerate=samplerate,
                   channels=1, dtype='int16')
    sd.wait()
    wav.write(filename, samplerate, audio)
```
Instalar: `pip install sounddevice scipy`

### 2. Rutas de archivos
Los scripts `.sh` en `Base/scripts/` son bash — no corren directo en Windows.
Las funciones principales están en los `.py` y funcionan cross-platform.

### 3. Whisper
Funciona igual en Windows, solo necesita ffmpeg en PATH.

### 4. HUD flotante
`ia vexa hud` → en Windows: `python VEXA\hud.py`
Requiere tkinter (incluido en Python estándar de Windows).

---

## Acceso desde el celular (misma WiFi)

1. Ver IP de la PC Windows: `ipconfig` → IPv4 del adaptador WiFi
2. Abrir en Chrome del celular: `http://TU-IP:8765/mobile.html`
3. Para micrófono en celular (requiere HTTPS):
   - Generar cert: `python VEXA\generar_ssl.py` (ver abajo)
   - Acceder: `https://TU-IP:8443/mobile.html`

### generar_ssl.py (crear en VEXA/)
```python
import subprocess, socket

def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    ip = s.getsockname()[0]
    s.close()
    return ip

ip = local_ip()
subprocess.run([
    "openssl", "req", "-x509", "-newkey", "rsa:2048",
    "-keyout", "ssl/key.pem", "-out", "ssl/cert.pem",
    "-days", "3650", "-nodes",
    "-subj", f"/CN=vexa.local",
    "-addext", f"subjectAltName=IP:{ip},IP:127.0.0.1"
])
print(f"Cert generado para IP: {ip}")
```

---

## Comandos de voz disponibles

| Comando | Acción |
|---------|--------|
| "modo chat" | Conversación normal con Ollama |
| "modo pc" | Control del PC via Claude Code |
| "modo agente" | Ejecuta agente autónomo |
| "describí la pantalla" | OCR + análisis con IA |
| "guarda que..." | Nota rápida en Obsidian |
| "resumí lo de ayer" | Resumen de conversaciones |
| "explícame X" | Modo profesor (guarda en Conocimiento/) |
| "para" / "silencio" | Interrumpir TTS |
| "estado del sistema" | Ver estado actual |

---

## Memoria persistente

VEXA guarda todo en `Obsidian/AI-Memory/`:
- `Conversaciones/YYYY-MM-DD.md` — diario automático
- `Conocimiento/` — temas aprendidos
- `nota-rapida.md` — notas de voz
- `Sistema/` — perfil, configuración, errores

Abrir la carpeta `Obsidian/` como vault en la app Obsidian para ver todo organizado.

---

## Troubleshooting

**Ollama no conecta** → verificar que `ollama serve` está corriendo (se abre automáticamente con el instalador Windows)

**Sin audio / TTS** → verificar que `edge-tts` está instalado: `edge-tts --list-voices`

**Whisper muy lento** → usar modelo más pequeño editando `voice_input.py`: cambiar `"base"` por `"tiny"`

**Puerto 8765 ocupado** → cambiar `HTTP_PORT` en `VEXA/ui_server.py`
