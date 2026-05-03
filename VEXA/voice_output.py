#!/usr/bin/env python3
"""Voice output for VEXA — TTS with edge-tts, chain de fallbacks para playback."""

import os
import queue
import re
import signal
import subprocess
import tempfile
import threading
from pathlib import Path

_SENTENCE_END = re.compile(r'(?<=[.!?;])\s+')

VENV       = Path("/home/mash/Opencode/Base/venv")
EDGE_TTS   = VENV / "bin" / "edge-tts"
DEFAULT_VOICE = "es-ES-AlvaroNeural"

# Cadena de players para intentar en orden
_PLAYERS = [
    ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "{file}"],
    ["mpv", "--no-video", "--really-quiet", "--ao=pulse", "{file}"],
    ["mpv", "--no-video", "--really-quiet", "--ao=alsa",  "{file}"],
    ["mpv", "--no-video", "--really-quiet", "{file}"],
]


def _cmd_exists(cmd: str) -> bool:
    try:
        subprocess.run(["which", cmd], check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        return False


class VoiceOutput:
    def __init__(self, voice: str = DEFAULT_VOICE):
        self.voice = voice
        self._has_edge   = EDGE_TTS.exists()
        self._has_espeak = _cmd_exists("espeak-ng")
        self._lock       = threading.Lock()
        self._current_proc: subprocess.Popen | None = None

    def interrupt(self):
        """Kill any currently playing audio immediately."""
        with self._lock:
            if self._current_proc and self._current_proc.poll() is None:
                try:
                    self._current_proc.send_signal(signal.SIGTERM)
                    self._current_proc.wait(timeout=1)
                except Exception:
                    try:
                        self._current_proc.kill()
                    except Exception:
                        pass
                self._current_proc = None

    def speak(self, text: str) -> bool:
        text = text.strip()
        if not text:
            return True

        if self._has_edge:
            success = self._speak_edge(text)
            if success:
                return True

        if self._has_espeak:
            return self._speak_espeak(text)

        print(f"[VOZ] {text}")
        return True

    def _play_file(self, path: str) -> bool:
        """Intenta reproducir el archivo con cada player disponible usando Popen."""
        for template in _PLAYERS:
            cmd = [c.replace("{file}", path) for c in template]
            if not _cmd_exists(cmd[0]):
                continue
            try:
                with self._lock:
                    proc = subprocess.Popen(
                        cmd,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    self._current_proc = proc

                proc.wait(timeout=90)

                with self._lock:
                    if self._current_proc is proc:
                        self._current_proc = None

                if proc.returncode in (0, -15):  # 0=ok, -15=SIGTERM (interrupt)
                    return proc.returncode == 0
            except (subprocess.TimeoutExpired, FileNotFoundError):
                with self._lock:
                    if self._current_proc is proc:
                        self._current_proc = None
                continue
        return False

    def _speak_edge(self, text: str) -> bool:
        tmp = tempfile.mktemp(suffix=".mp3")
        try:
            r = subprocess.run(
                [str(EDGE_TTS), "--text", text, "--voice", self.voice, "--write-media", tmp],
                capture_output=True, timeout=30
            )
            if r.returncode != 0:
                print(f"[VoiceOutput] edge-tts falló (code {r.returncode})")
                return False

            if not self._play_file(tmp):
                print("[VoiceOutput] Ningún player pudo reproducir el audio")
                return False

            return True
        except subprocess.TimeoutExpired:
            print("[VoiceOutput] edge-tts timeout")
            return False
        except Exception as e:
            print(f"[VoiceOutput] Error: {e}")
            return False
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass

    def speak_sentences(self, chunks_iter) -> str:
        """Pipeline de streaming: habla cada oración mientras el modelo sigue generando.

        Acepta un iterable de strings (chunks del LLM). Solapea la generación del
        siguiente chunk con la síntesis TTS de la oración anterior. Devuelve el
        texto completo ensamblado.
        """
        tts_queue: queue.Queue = queue.Queue()
        full: list[str] = []

        def _tts_worker():
            while True:
                sentence = tts_queue.get()
                if sentence is None:
                    tts_queue.task_done()
                    break
                self.speak(sentence)
                tts_queue.task_done()

        worker = threading.Thread(target=_tts_worker, daemon=True)
        worker.start()

        buffer = ""
        for chunk in chunks_iter:
            buffer += chunk
            full.append(chunk)
            parts = _SENTENCE_END.split(buffer)
            if len(parts) > 1:
                for sentence in parts[:-1]:
                    s = sentence.strip()
                    if s:
                        tts_queue.put(s)
                buffer = parts[-1]

        if buffer.strip():
            tts_queue.put(buffer.strip())

        tts_queue.put(None)
        worker.join()
        return "".join(full)

    def _speak_espeak(self, text: str) -> bool:
        try:
            cmd = ["espeak-ng", "-s", "140", "-v", "es-la", text]
            with self._lock:
                proc = subprocess.Popen(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                self._current_proc = proc

            proc.wait(timeout=30)

            with self._lock:
                if self._current_proc is proc:
                    self._current_proc = None

            return proc.returncode in (0, -15)
        except Exception as e:
            print(f"[VoiceOutput] espeak error: {e}")
            return False
