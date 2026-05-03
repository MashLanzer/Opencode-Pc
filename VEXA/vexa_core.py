#!/usr/bin/env python3
"""
VEXA Core — Orquestador principal del sistema
Uso: python3 VEXA/vexa_core.py [--no-voice] [--no-ui] [--no-wake]
"""

import asyncio
import datetime
import logging
import signal
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from state_manager import StateManager, VexaState
from ollama_client import OllamaClient
from voice_input import VoiceInput
from voice_output import VoiceOutput
from command_library import detect_intent, get_help_text
from opencode_bridge import OpenCodeBridge
from ui_server import UIServer
from wake_word import contains_wake_word, strip_wake_word
from memory_search import MemorySearch

BASE_SCRIPTS  = Path("/home/mash/Opencode/Base/scripts")
MEMORY_DIR    = Path("/home/mash/Opencode/Obsidian/AI-Memory/Conversaciones")

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "vexa.log"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("VEXA")


class VexaCore:
    def __init__(self, no_voice: bool = False, no_ui: bool = False, wake_mode: bool = True):
        self.no_voice  = no_voice
        self.no_ui     = no_ui
        self.wake_mode = wake_mode   # True = solo responde con wake word
        self._running  = False

        self.state    = StateManager()
        self.ollama   = OllamaClient(model="llama3.2:1b")
        self.memory   = MemorySearch()
        self.voice_in = VoiceInput(model="base") if not no_voice else None
        self.voice_out= VoiceOutput()             if not no_voice else None
        self.opencode = OpenCodeBridge()
        self._cmd_queue: asyncio.Queue = asyncio.Queue()
        self.ui = UIServer(
            state_manager=self.state,
            voice_output=self.voice_out,
            command_queue=self._cmd_queue,
        ) if not no_ui else None

        self.state.subscribe(self._on_state_change)

    # ── Estado ────────────────────────────────────────────────────────
    async def _on_state_change(self, new_state: VexaState, metadata: dict):
        log.info(f"Estado → {new_state.value}")
        if self.ui:
            await UIServer.broadcast({"type": "state_change", "state": new_state.value})

    # ── Voz ───────────────────────────────────────────────────────────
    def say(self, text: str):
        log.info(f"[VOZ] {text}")
        if self.voice_out:
            self.voice_out.speak(text)
        else:
            print(f"VEXA: {text}")

    async def async_say(self, text: str):
        await UIServer.broadcast({"type": "response", "text": text})
        await asyncio.get_event_loop().run_in_executor(None, self.say, text)

    # ── Procesamiento ─────────────────────────────────────────────────
    async def process(self, text: str):
        intent, _ = detect_intent(text)
        log.info(f"Input: '{text}' | Intent: {intent}")

        if intent == "salir":
            await self.shutdown()
            return

        if intent == "parar":
            if self.voice_out:
                self.voice_out.interrupt()
            await self.state.set_state(VexaState.IDLE)
            return

        if intent == "modo_pc":
            await self.state.set_state(VexaState.PC_CONTROL)
            await self.async_say("Modo control de PC activado.")
            if not self.opencode.is_running:
                self.opencode.start()
            return

        if intent == "modo_agente":
            await self.state.set_state(VexaState.AGENT)
            await self.async_say("Modo agente activado. Dame una tarea.")
            return

        if intent == "modo_chat":
            await self.state.set_state(VexaState.IDLE)
            self.ollama.reset()
            await self.async_say("Modo chat. ¿En qué te ayudo?")
            return

        if intent == "limpiar_historial":
            self.ollama.reset()
            await self.async_say("Historial borrado. Empezamos de cero.")
            return

        if intent == "estado":
            models = self.ollama.list_models()
            wake_str = "wake word activo" if self.wake_mode else "escucha continua"
            await self.async_say(
                f"Sistema VEXA activo. Estado: {self.state.state_name}. "
                f"Modelo: {models[0] if models else 'no disponible'}. {wake_str}."
            )
            return

        if intent == "ayuda":
            await self.async_say(get_help_text())
            return

        if intent == "recordatorio":
            await self._handle_recordatorio(text)
            return

        if intent == "guardar_nota":
            await self._handle_guardar_nota(text)
            return

        if intent == "multimodal":
            await self._handle_multimodal(text)
            return

        if intent == "historial":
            await self._handle_historial(text)
            return

        if intent == "aprender":
            await self._handle_aprender(text)
            return

        if intent == "guardar_captura":
            await self._handle_guardar_captura(text)
            return

        if intent == "toggle_wake":
            self.wake_mode = not self.wake_mode
            modo = "activado — di 'oye VEXA' para hablar" if self.wake_mode else "desactivado — escucho todo"
            await self.async_say(f"Wake word {modo}.")
            return

        # Modo PC Control
        if self.state.state == VexaState.PC_CONTROL:
            await self.state.set_state(VexaState.THINKING)
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(None, self.opencode.send, text)
            spoken = result[:250] if result else "Comando ejecutado."
            await self.state.set_state(VexaState.SPEAKING)
            await self.async_say(spoken)
            loop.run_in_executor(None, self._log_episode, text, spoken, "pc_control")
            await self.state.set_state(VexaState.PC_CONTROL)
            return

        # Default: chat con Ollama + contexto de memoria — pipeline de streaming
        await self.state.set_state(VexaState.THINKING)
        loop = asyncio.get_event_loop()

        memory_context = await loop.run_in_executor(None, self.memory.build_context, text)

        original_system = self.ollama.system_prompt
        if memory_context:
            log.info(f"[Memoria] Contexto inyectado para: {text[:40]}")
            self.ollama.set_system(original_system + "\n\n" + memory_context)

        # Transición a SPEAKING antes de empezar TTS — la UI reacciona de inmediato
        await self.state.set_state(VexaState.SPEAKING)

        response = ""
        try:
            if self.voice_out:
                stream = self.ollama.chat_stream(text)
                response = await loop.run_in_executor(
                    None, self.voice_out.speak_sentences, stream
                )
            else:
                response = await loop.run_in_executor(None, self.ollama.chat, text)
        except Exception as e:
            log.error(f"[Chat] Error generando respuesta: {e}")
            response = f"Hubo un error: {e}"

        if memory_context:
            self.ollama.set_system(original_system)

        log.info(f"[Respuesta] {response[:80]}...")
        await UIServer.broadcast({"type": "response", "text": response})
        from ui_server import _ws_clients
        log.info(f"[WS] Broadcast enviado a {len(_ws_clients)} clientes")
        loop.run_in_executor(None, self._log_episode, text, response, "voz")
        await self.state.set_state(VexaState.IDLE)

    # ─────────────────────────────────────────────────────────────────
    # OPCIÓN 3 — Historial inteligente de sesiones
    # ─────────────────────────────────────────────────────────────────
    async def _handle_historial(self, text: str):
        """Lee el archivo de conversaciones de ayer/hoy y lo resume con Ollama."""
        import re as _re

        # Detectar qué fecha pide
        t = text.lower()
        if any(w in t for w in ("ayer", "anoche", "sesión anterior")):
            fecha = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
            label = "ayer"
        elif "semana" in t:
            # últimos 7 días — concatenar todos
            fecha = None
            label = "esta semana"
        else:
            fecha = datetime.date.today().isoformat()
            label = "hoy"

        await self.state.set_state(VexaState.THINKING)
        loop = asyncio.get_event_loop()

        def _leer_historial() -> str:
            if fecha:
                f = MEMORY_DIR / f"{fecha}.md"
                if not f.exists():
                    return ""
                return f.read_text(encoding="utf-8")
            else:
                # semana: concatenar últimos 7 días
                partes = []
                for i in range(7):
                    d = (datetime.date.today() - datetime.timedelta(days=i)).isoformat()
                    f = MEMORY_DIR / f"{d}.md"
                    if f.exists():
                        partes.append(f.read_text(encoding="utf-8")[:1500])
                return "\n".join(partes)

        raw = await loop.run_in_executor(None, _leer_historial)
        if not raw.strip():
            await self.async_say(f"No encontré conversaciones de {label}.")
            await self.state.set_state(VexaState.IDLE)
            return

        # Extraer solo líneas del usuario para el prompt
        user_lines = [l.replace("**Tú:**", "").strip()
                      for l in raw.splitlines() if l.startswith("**Tú:**")]
        context = "\n".join(user_lines[:30])

        prompt = (
            f"Resumí en 3 puntos concisos qué hizo y de qué habló Mash {label}. "
            f"Conversaciones:\n{context[:2000]}\n\n"
            "Responde en español, máximo 4 oraciones, tono directo."
        )

        await self.state.set_state(VexaState.SPEAKING)
        if self.voice_out:
            stream = self.ollama.chat_stream(prompt)
            response = await loop.run_in_executor(None, self.voice_out.speak_sentences, stream)
        else:
            response = await loop.run_in_executor(None, self.ollama.generate, prompt)
            print(f"VEXA: {response}")

        await UIServer.broadcast({"type": "response", "text": response})
        loop.run_in_executor(None, self._log_episode, text, response, "historial")
        await self.state.set_state(VexaState.IDLE)

    # ─────────────────────────────────────────────────────────────────
    # OPCIÓN 5 — Profesor personal (modo aprendizaje)
    # ─────────────────────────────────────────────────────────────────
    async def _handle_aprender(self, text: str):
        """Explica el tema, guarda la explicación en Obsidian/Conocimiento/."""
        import re as _re

        # Extraer el tema de la pregunta
        tema_raw = _re.sub(
            r"^(?:explícame|explicame|explicá|explica|enseñame|enséñame|"
            r"quiero aprender|quiero entender|quiero saber|"
            r"aprende conmigo|no entiendo|qué es|cómo funciona|por qué)"
            r"[\s:,]+(?:cómo |qué |sobre |que |como )?",
            "", text, flags=_re.I
        ).strip(" .,?¿")
        tema = tema_raw if tema_raw else text

        await self.state.set_state(VexaState.THINKING)
        loop = asyncio.get_event_loop()

        # System prompt de profesor — adaptado al nivel de Mash
        profesor_prompt = (
            "Eres VEXA en modo profesor. Explica el tema de forma clara, con ejemplos "
            "concretos y analogías cuando ayude. Adapta la profundidad al contexto del "
            "sistema (Linux, Python, D&D, Godot según corresponda). "
            "Habla en español. Al final añade una pregunta de seguimiento para verificar comprensión."
        )

        original_system = self.ollama.system_prompt
        self.ollama.set_system(profesor_prompt)

        await self.state.set_state(VexaState.SPEAKING)
        if self.voice_out:
            stream = self.ollama.chat_stream(tema)
            response = await loop.run_in_executor(None, self.voice_out.speak_sentences, stream)
        else:
            response = await loop.run_in_executor(None, self.ollama.chat, tema)
            print(f"VEXA: {response}")

        self.ollama.set_system(original_system)

        # Guardar en Obsidian/Conocimiento/
        def _guardar_conocimiento():
            try:
                conocimiento_dir = MEMORY_DIR.parent / "Conocimiento"
                conocimiento_dir.mkdir(exist_ok=True)
                # Nombre limpio para el archivo
                nombre = _re.sub(r"[^\w\s-]", "", tema[:40]).strip().replace(" ", "-").lower()
                if not nombre:
                    nombre = datetime.date.today().isoformat()
                archivo = conocimiento_dir / f"{nombre}.md"
                now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
                contenido = (
                    f"# {tema.capitalize()}\n\n"
                    f"> Aprendido el {now} via VEXA\n\n"
                    f"{response}\n\n"
                    f"---\n*Pregunta: {text}*\n"
                )
                modo = "a" if archivo.exists() else "w"
                with open(archivo, modo, encoding="utf-8") as f:
                    if modo == "a":
                        f.write(f"\n\n---\n\n## Sesión {now}\n\n{response}\n")
                    else:
                        f.write(contenido)
                log.info(f"[Aprendizaje] Guardado en {archivo.name}")
            except Exception as e:
                log.error(f"[Aprendizaje] Error guardando: {e}")

        await loop.run_in_executor(None, _guardar_conocimiento)
        await UIServer.broadcast({"type": "response", "text": response})
        loop.run_in_executor(None, self._log_episode, text, response, "aprendizaje")
        await self.state.set_state(VexaState.IDLE)

    # ─────────────────────────────────────────────────────────────────
    # OPCIÓN 6 — Captura de pantalla con guardado en Obsidian
    # ─────────────────────────────────────────────────────────────────
    async def _handle_guardar_captura(self, text: str):
        """Captura la ventana activa, guarda en Obsidian/Capturas/ y loguea."""
        import shutil

        await self.state.set_state(VexaState.THINKING)

        if not shutil.which("scrot"):
            await self.async_say("Necesito scrot para capturar. Instalalo con sudo apt install scrot.")
            await self.state.set_state(VexaState.IDLE)
            return

        loop = asyncio.get_event_loop()

        def _capturar() -> tuple:
            capturas_dir = MEMORY_DIR.parent / "Capturas"
            capturas_dir.mkdir(exist_ok=True)
            ts   = datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
            dest = capturas_dir / f"{ts}.png"

            # Intentar captura de ventana activa (-u), si falla captura completa
            r = subprocess.run(["scrot", "-u", "-z", str(dest)],
                               capture_output=True, timeout=5)
            if r.returncode != 0:
                r = subprocess.run(["scrot", str(dest)],
                                   capture_output=True, timeout=5)

            if r.returncode != 0 or not dest.exists():
                return None, None

            # Detectar nombre de ventana activa
            win_name = ""
            try:
                xdotool = shutil.which("xdotool")
                if xdotool:
                    out = subprocess.run(
                        [xdotool, "getactivewindow", "getwindowname"],
                        capture_output=True, text=True, timeout=3
                    )
                    win_name = out.stdout.strip()[:60]
            except Exception:
                pass

            return dest, win_name

        dest, win_name = await loop.run_in_executor(None, _capturar)

        if not dest:
            await self.async_say("No pude hacer la captura.")
            await self.state.set_state(VexaState.IDLE)
            return

        # Registrar en nota rápida
        def _registrar():
            nota_file = MEMORY_DIR.parent / "nota-rapida.md"
            now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
            win_str = f" ({win_name})" if win_name else ""
            entry = f"\n## {now} — Captura\nGuardé captura{win_str}: `{dest.name}`\n"
            with open(nota_file, "a", encoding="utf-8") as f:
                f.write(entry)

        await loop.run_in_executor(None, _registrar)

        win_msg = f" de {win_name}" if win_name else ""
        respuesta = f"Captura{win_msg} guardada en Obsidian."
        await self.async_say(respuesta)
        log.info(f"[Captura] {dest}")

        # Notificación de escritorio con la ruta
        subprocess.run(
            ["notify-send", "--app-name=VEXA", "Captura guardada", str(dest)],
            capture_output=True
        )

        loop.run_in_executor(None, self._log_episode, text, respuesta, "captura")
        await self.state.set_state(VexaState.IDLE)

    async def _handle_guardar_nota(self, text: str):
        """Guarda una nota rápida en Obsidian directamente desde voz."""
        import re as _re
        # Extraer el contenido después del trigger
        nota = _re.sub(
            r"^(?:guarda|anota|recuerda|apunta|nota|apunte|no te olvides)[:\s]+(?:que\s+)?",
            "", text, flags=_re.I
        ).strip()
        if not nota:
            await self.async_say("¿Qué querés que guarde?")
            return

        nota_file = Path("/home/mash/Opencode/Obsidian/AI-Memory/nota-rapida.md")
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        try:
            with open(nota_file, "a", encoding="utf-8") as f:
                f.write(f"\n## {now}\n{nota}\n")
            await self.async_say(f"Guardado: {nota[:60]}")
            log.info(f"[Nota] Guardada: {nota[:60]}")
        except Exception as e:
            await self.async_say("No pude guardar la nota.")
            log.error(f"[Nota] Error: {e}")

    async def _handle_recordatorio(self, text: str):
        """Delega al script ia-recordatorio.sh."""
        script = BASE_SCRIPTS / "ia-recordatorio.sh"
        if not script.exists():
            await self.async_say("El sistema de recordatorios no está instalado.")
            return
        await self.async_say("Procesando recordatorio.")
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: subprocess.run(["bash", str(script), text], capture_output=False),
        )

    async def _handle_multimodal(self, text: str):
        """Captura pantalla → OCR + análisis Ollama en streaming."""
        import shutil, tempfile

        await self.state.set_state(VexaState.THINKING)

        if not shutil.which("scrot"):
            await self.async_say("Necesito scrot. Instalalo con: sudo apt install scrot")
            await self.state.set_state(VexaState.IDLE)
            return
        if not shutil.which("tesseract"):
            await self.async_say("Necesito tesseract. Instalalo con: sudo apt install tesseract-ocr tesseract-ocr-spa")
            await self.state.set_state(VexaState.IDLE)
            return

        loop = asyncio.get_event_loop()

        def _capture_ocr():
            with tempfile.TemporaryDirectory() as d:
                img = f"{d}/screen.png"
                # Intentar capturar solo la ventana activa primero
                r = subprocess.run(["scrot", "-u", "-z", img],
                                   capture_output=True, timeout=5)
                if r.returncode != 0:
                    r = subprocess.run(["scrot", img],
                                       capture_output=True, timeout=5)
                if r.returncode != 0:
                    return None, None

                r2 = subprocess.run(
                    ["tesseract", img, "stdout", "-l", "spa+eng"],
                    capture_output=True, text=True, timeout=30
                )
                ocr = r2.stdout.strip() if r2.returncode == 0 else ""
                return ocr, img

        ocr_text, _ = await loop.run_in_executor(None, _capture_ocr)

        if not ocr_text:
            await self.async_say("No encontré texto en la pantalla. Intentá con una ventana que tenga texto visible.")
            await self.state.set_state(VexaState.IDLE)
            return

        log.info(f"[OCR] {len(ocr_text)} chars capturados")

        # Prompt enriquecido con contexto de la pregunta
        prompt = (
            f"El usuario dijo: '{text}'\n\n"
            f"Texto extraído de la pantalla (OCR):\n---\n{ocr_text[:2500]}\n---\n\n"
            "Responde de forma directa y útil en español. "
            "Si es un error, explica qué significa y cómo solucionarlo. "
            "Si es código, explícalo brevemente. Si es texto general, resume."
        )

        await self.state.set_state(VexaState.SPEAKING)
        if self.voice_out:
            stream = self.ollama.chat_stream(prompt)
            response = await loop.run_in_executor(
                None, self.voice_out.speak_sentences, stream
            )
        else:
            response = await loop.run_in_executor(None, self.ollama.generate, prompt)
            print(f"VEXA: {response}")

        await UIServer.broadcast({"type": "response", "text": response})
        loop.run_in_executor(None, self._log_episode, text, response, "pantalla")
        await self.state.set_state(VexaState.IDLE)

    # ── Loop de voz ───────────────────────────────────────────────────
    async def voice_loop(self):
        _device_errors = 0

        if self.wake_mode:
            log.info("[WAKE] Modo wake word activo — di 'oye VEXA' para hablar")
        else:
            log.info("[WAKE] Escucha continua activa")

        while self._running:
            await self.state.set_state(VexaState.LISTENING)
            loop = asyncio.get_event_loop()

            try:
                raw = await loop.run_in_executor(None, self.voice_in.listen, 5)
                _device_errors = 0
            except RuntimeError as e:
                _device_errors += 1
                log.warning(f"Micrófono: {e} (intento {_device_errors})")
                if _device_errors % 5 == 0:
                    new_dev = await loop.run_in_executor(None, self.voice_in.refresh_device)
                    log.info(f"[Audio] Re-detectando dispositivo → {new_dev}")
                await self.state.set_state(VexaState.IDLE)
                await asyncio.sleep(min(2 * _device_errors, 15))
                continue

            if not raw.strip():
                await self.state.set_state(VexaState.IDLE)
                await asyncio.sleep(0.3)
                continue

            # ── Wake word ──────────────────────────────────────────
            if self.wake_mode:
                if not contains_wake_word(raw):
                    # Sin wake word: ignorar silenciosamente
                    await self.state.set_state(VexaState.IDLE)
                    continue

                # Extraer el comando que viene después del wake word
                command = strip_wake_word(raw)
                if not command.strip():
                    # Solo dijo el wake word — confirmar escucha y esperar
                    await self.async_say("Dime.")
                    try:
                        follow = await loop.run_in_executor(None, self.voice_in.listen, 7)
                        if follow.strip():
                            await self.process(follow)
                    except RuntimeError:
                        pass
                    continue
            else:
                command = raw

            await self.process(command)

    # ── Loop de comandos API ──────────────────────────────────────────
    async def command_loop(self):
        while self._running:
            try:
                kind, payload = await asyncio.wait_for(self._cmd_queue.get(), timeout=1.0)
                if kind == "command":
                    await self.process(payload)
                elif kind == "state":
                    try:
                        await self.state.set_state(VexaState[payload])
                    except KeyError:
                        log.warning(f"Estado desconocido: {payload}")
            except asyncio.TimeoutError:
                continue

    # ── Startup / Shutdown ────────────────────────────────────────────
    async def startup(self):
        log.info("=== VEXA iniciando ===")

        if self.ui:
            self.ui.start_http()
            await self.ui.start_ws()

        if self.ollama.is_available():
            log.info(f"Ollama OK — modelos: {self.ollama.list_models()}")
        else:
            log.warning("Ollama no disponible — modo degradado")

        if self.memory.is_available:
            log.info("Memoria RAG disponible")
        else:
            log.info("Memoria RAG no indexada — ejecuta: ia rag index")

        await self.state.set_state(VexaState.IDLE)

        wake_str = "Di 'oye VEXA' para hablar." if self.wake_mode else "Escucha continua activa."
        await self.async_say(f"Sistema VEXA iniciado. {wake_str}")

        # Mostrar URL móvil en log para acceso fácil
        from ui_server import LOCAL_IP
        log.info(f"[Móvil] Acceso desde teléfono → http://{LOCAL_IP}:8765/mobile.html")

        # Resumen matutino + reporte nocturno (solo por las mañanas)
        hour = datetime.datetime.now().hour
        if 5 <= hour < 13:
            loop = asyncio.get_event_loop()
            asyncio.create_task(self._morning_briefing())

    async def run(self):
        self._running = True

        for sig in (signal.SIGINT, signal.SIGTERM):
            asyncio.get_event_loop().add_signal_handler(
                sig, lambda: asyncio.create_task(self.shutdown())
            )

        await self.startup()

        tasks = [asyncio.create_task(self.command_loop())]
        if self.voice_in:
            tasks.append(asyncio.create_task(self.voice_loop()))

        try:
            await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            pass
        finally:
            if self.ui:
                self.ui.stop()

    async def _morning_briefing(self):
        """Resumen hablado al arrancar por la mañana — tareas, ayer, reporte nocturno."""
        await asyncio.sleep(3)  # dejar que el saludo termine
        loop = asyncio.get_event_loop()

        def _build_briefing() -> str:
            today     = datetime.date.today()
            yesterday = today - datetime.timedelta(days=1)
            lines: list[str] = []

            # 1. Reporte del agente nocturno
            nocturno = Path("/home/mash/Opencode/Obsidian/AI-Memory/Sistema/reporte-nocturno.md")
            flag     = Path("/tmp/vexa-morning-report.flag")
            if flag.exists():
                try:
                    if flag.read_text().strip() == today.isoformat():
                        lines.append("El agente nocturno dejó un reporte.")
                        flag.unlink(missing_ok=True)
                except Exception:
                    pass

            # 2. Tareas pendientes
            tareas_file = MEMORY_DIR.parent / "tareas-pendientes.md"
            if tareas_file.exists():
                content = tareas_file.read_text(encoding="utf-8")
                pending = content.count("- [ ]")
                done    = content.count("- [x]")
                if pending:
                    lines.append(f"Tenés {pending} tarea{'s' if pending > 1 else ''} pendiente{'s' if pending > 1 else ''}.")

            # 3. Resumen de lo que hablaste ayer
            ayer_file = MEMORY_DIR / f"{yesterday.isoformat()}.md"
            ayer_context = ""
            if ayer_file.exists():
                ayer_text = ayer_file.read_text(encoding="utf-8")
                # Extraer solo las líneas "Tú:"
                user_lines = [l.replace("**Tú:**", "").strip()
                              for l in ayer_text.splitlines()
                              if l.startswith("**Tú:**")]
                if user_lines:
                    ayer_context = " / ".join(user_lines[:5])

            if not lines and not ayer_context:
                return ""  # nada interesante que decir

            # Construir prompt para Ollama
            context_parts = []
            if lines:
                context_parts.append(". ".join(lines))
            if ayer_context:
                context_parts.append(f"Ayer hablamos de: {ayer_context[:300]}")

            prompt = (
                "Generá un saludo matutino breve para Mash en español. "
                "Máximo 2 oraciones, tono cálido y directo. "
                f"Contexto: {'. '.join(context_parts)}. "
                "No empieces con 'Buenos días' literalmente, sé creativo y natural."
            )

            try:
                response = "".join(self.ollama.chat_stream(prompt))
                return response.strip()
            except Exception:
                return ". ".join(lines) if lines else ""

        briefing = await loop.run_in_executor(None, _build_briefing)
        if briefing:
            log.info(f"[Mañana] {briefing}")
            await self.async_say(briefing)
            # Notificación de escritorio también
            subprocess.run(
                ["notify-send", "--app-name=VEXA", "Buenos días, Mash", briefing],
                capture_output=True
            )

    def _log_episode(self, user_input: str, response: str, source: str = "voz"):
        """Guarda el intercambio en el diario de conversaciones de Obsidian."""
        try:
            MEMORY_DIR.mkdir(parents=True, exist_ok=True)
            today = datetime.date.today().isoformat()
            now   = datetime.datetime.now().strftime("%H:%M:%S")
            file  = MEMORY_DIR / f"{today}.md"

            # Crear encabezado del día si el archivo es nuevo
            if not file.exists():
                file.write_text(f"# Conversaciones — {today}\n\n", encoding="utf-8")

            entry = (
                f"## {now} [{source}]\n"
                f"**Tú:** {user_input}\n\n"
                f"**VEXA:** {response}\n\n"
                f"---\n\n"
            )
            with open(file, "a", encoding="utf-8") as f:
                f.write(entry)
        except Exception as e:
            log.debug(f"[Episodio] No se pudo guardar: {e}")

    async def shutdown(self):
        log.info("Apagando VEXA...")
        self._running = False
        self.opencode.stop()
        await self.async_say("Hasta luego, Mash.")
        await self.state.set_state(VexaState.IDLE)


# ── Entry point ───────────────────────────────────────────────────────
if __name__ == "__main__":
    no_voice  = "--no-voice" in sys.argv
    no_ui     = "--no-ui"    in sys.argv
    no_wake   = "--no-wake"  in sys.argv

    vexa = VexaCore(no_voice=no_voice, no_ui=no_ui, wake_mode=not no_wake)
    asyncio.run(vexa.run())
