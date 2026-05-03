#!/usr/bin/env python3
"""Voice input for VEXA — STT using Whisper con detección de silencio."""

import array
import math
import os
import re
import subprocess
import tempfile
import wave
from pathlib import Path
from typing import Optional

VENV        = Path("/home/mash/Opencode/Base/venv")
WHISPER_BIN = VENV / "bin" / "whisper"

# Umbral de energía RMS mínima para considerar que hay voz
# (valor empírico: ruido de fondo ~200-500, voz ~2000+)
SILENCE_THRESHOLD = 800

# Palabras que Whisper alucina en silencio (filtrar)
HALLUCINATION_PHRASES = {
    "gracias", "suscríbete", "subtítulos", "subtitulos",
    "amara.org", "transcripción", "transcripcion",
}


def detect_audio_device() -> Optional[str]:
    """Detecta dispositivo de captura ALSA.

    Prioridad: micrófono USB dedicado > otro USB > integrado.
    Penaliza dispositivos de cámara (FHD, webcam, camera).
    """
    _CAMERA_WORDS = {"camera", "cam", "fhd", "webcam", "video"}

    def _score(line: str) -> int:
        l = line.lower()
        is_usb    = "usb" in l
        is_camera = any(w in l for w in _CAMERA_WORDS)
        if is_usb and not is_camera:
            return 2
        if is_usb:
            return 1
        return 0

    try:
        out = subprocess.run(["arecord", "-l"], capture_output=True, text=True)
        candidates = []
        for line in out.stdout.splitlines():
            m = re.search(
                r"tarjeta\s+(\d+).*dispositivo\s+(\d+)|card\s+(\d+).*device\s+(\d+)",
                line, re.I
            )
            if m:
                card = m.group(1) or m.group(3)
                dev  = m.group(2) or m.group(4)
                candidates.append((_score(line), f"hw:{card},{dev}"))
        if not candidates:
            return None
        candidates.sort(key=lambda x: x[0], reverse=True)
        chosen = candidates[0][1]
        print(f"[Audio] Dispositivo detectado: {chosen} (score={candidates[0][0]})")
        return chosen
    except Exception:
        pass
    return None


def audio_rms(wav_path: str) -> float:
    """Calcula la energía RMS del archivo WAV. 0 si no se puede leer."""
    try:
        with wave.open(wav_path, "rb") as wf:
            frames = wf.readframes(wf.getnframes())
            samples = array.array("h", frames)
        if not samples:
            return 0.0
        return math.sqrt(sum(x * x for x in samples) / len(samples))
    except Exception:
        return 0.0


def is_hallucination(text: str) -> bool:
    """Devuelve True si Whisper probablemente alucinó (silencio o ruido)."""
    t = text.lower().strip()
    # Normalizar: quitar puntuación para comparar palabras limpias
    words = re.sub(r"[^\w\s]", "", t).split()
    # Texto repetitivo (ej: "concha concha concha")
    if len(words) >= 3 and len(set(words)) == 1:
        return True
    # Frases conocidas de alucinación de Whisper en silencio
    if any(p in t for p in HALLUCINATION_PHRASES):
        return True
    return False


class VoiceInput:
    def __init__(
        self,
        device:    str  = None,
        language:  str  = "es",
        duration:  int  = 5,
        model:     str  = "tiny",
    ):
        self.device   = device or detect_audio_device() or "hw:0,0"
        self.language = language
        self.duration = duration
        self.model    = model      # "small" = mejor español; "tiny" = más rápido
        self._whisper_ok = WHISPER_BIN.exists()
        print(f"[VoiceInput] Dispositivo: {self.device}  modelo Whisper: {self.model}")

    def refresh_device(self) -> Optional[str]:
        """Re-detecta el dispositivo de audio. Útil si el micrófono cambió."""
        new = detect_audio_device()
        if new and new != self.device:
            print(f"[VoiceInput] Dispositivo actualizado: {self.device} → {new}")
            self.device = new
        return self.device

    # ── Grabación ─────────────────────────────────────────────────────
    def record(self, duration: int = None) -> Optional[str]:
        """Graba audio y devuelve ruta al WAV 16kHz, o None si falla."""
        duration = duration or self.duration
        raw = tempfile.mktemp(suffix="_raw.wav")
        out = tempfile.mktemp(suffix="_16k.wav")
        try:
            subprocess.run(
                ["arecord", "-D", self.device, "-f", "S16_LE",
                 "-r", "48000", "-c", "1", "-d", str(duration), raw],
                check=True, capture_output=True, timeout=duration + 5
            )
            subprocess.run(
                ["ffmpeg", "-y", "-i", raw, "-ar", "16000", out],
                check=True, capture_output=True, timeout=15
            )
            return out
        except subprocess.CalledProcessError as e:
            print(f"[VoiceInput] Error grabando: {e}")
            return None
        finally:
            try:
                os.unlink(raw)
            except OSError:
                pass

    # ── Transcripción ─────────────────────────────────────────────────
    def transcribe(self, audio_path: str) -> str:
        """Transcribe el WAV a texto. Filtra silencio antes de llamar a Whisper."""
        if not self._whisper_ok:
            return ""

        # Detección de silencio — evita llamar a Whisper innecesariamente
        rms = audio_rms(audio_path)
        if rms < SILENCE_THRESHOLD:
            return ""

        out_dir = os.path.dirname(audio_path)
        try:
            subprocess.run(
                [
                    str(WHISPER_BIN), audio_path,
                    "--model",                  self.model,
                    "--language",               self.language,
                    "--output_format",          "txt",
                    "--output_dir",             out_dir,
                    "--condition_on_previous_text", "False",
                    "--no_speech_threshold",    "0.6",
                ],
                capture_output=True, text=True,
                timeout=90,   # 90s: suficiente incluso para cold start de "base"
            )
        except subprocess.TimeoutExpired:
            print("[VoiceInput] Whisper timeout — considera usar --model tiny")
            return ""
        except Exception as e:
            print(f"[VoiceInput] Error transcribiendo: {e}")
            return ""

        base = os.path.splitext(audio_path)[0]
        txt  = base + ".txt"
        if not os.path.exists(txt):
            return ""

        text = open(txt).read().strip()
        os.unlink(txt)

        # Filtrar alucinaciones comunes de Whisper en silencio
        if is_hallucination(text):
            return ""

        return text

    # ── API principal ─────────────────────────────────────────────────
    def listen(self, duration: int = None) -> str:
        """Graba y transcribe. Lanza RuntimeError si el dispositivo falla."""
        audio = self.record(duration)
        if audio is None:
            raise RuntimeError(f"No se pudo grabar desde {self.device}")
        try:
            return self.transcribe(audio)
        finally:
            try:
                os.unlink(audio)
            except OSError:
                pass
