#!/usr/bin/env python3
"""Ollama client for VEXA — LLM communication via local API."""

import json
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional

OLLAMA_URL = "http://127.0.0.1:11434"
DEFAULT_MODEL = "llama3.2:1b"
SYSTEM_PROMPT = (
    "Eres VEXA, una IA de voz personal que asiste a Brian (Mash) en español. "
    "Responde de forma concisa, natural y útil. Nunca uses markdown en tus respuestas "
    "de voz — solo texto plano. Sé directa y breve."
)

_HISTORY_FILE = Path(__file__).parent / "logs" / "history.json"
_MAX_HISTORY = 20


class OllamaClient:
    def __init__(self, model: str = DEFAULT_MODEL, base_url: str = OLLAMA_URL):
        self.model = model
        self.base_url = base_url
        self.system_prompt = SYSTEM_PROMPT
        self._history: list = []
        self._load_history()

    def _load_history(self):
        try:
            if _HISTORY_FILE.exists():
                self._history = json.loads(_HISTORY_FILE.read_text())[-_MAX_HISTORY:]
        except Exception:
            self._history = []

    def _save_history(self):
        try:
            _HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
            _HISTORY_FILE.write_text(json.dumps(self._history[-_MAX_HISTORY:], ensure_ascii=False))
        except Exception:
            pass

    def is_available(self) -> bool:
        try:
            urllib.request.urlopen(f"{self.base_url}/api/tags", timeout=3)
            return True
        except Exception:
            return False

    def list_models(self) -> list:
        try:
            with urllib.request.urlopen(f"{self.base_url}/api/tags", timeout=5) as r:
                return [m["name"] for m in json.loads(r.read()).get("models", [])]
        except Exception:
            return []

    def generate(self, prompt: str, system: str = None) -> str:
        payload = json.dumps({
            "model":  self.model,
            "prompt": prompt,
            "system": system or self.system_prompt,
            "stream": False,
        }).encode()
        req = urllib.request.Request(
            f"{self.base_url}/api/generate",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read()).get("response", "")
        except Exception as e:
            return f"[Error Ollama: {e}]"

    def chat(self, user_message: str) -> str:
        """Respuesta completa (sin streaming). Útil para llamadas programáticas."""
        return "".join(self.chat_stream(user_message))

    def chat_stream(self, user_message: str):
        """Genera la respuesta token a token. Devuelve un generator de strings."""
        self._history.append({"role": "user", "content": user_message})
        payload = json.dumps({
            "model":    self.model,
            "messages": [{"role": "system", "content": self.system_prompt}] + self._history,
            "stream":   True,
        }).encode()
        req = urllib.request.Request(
            f"{self.base_url}/api/chat",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        full: list[str] = []
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                for raw_line in r:
                    line = raw_line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except Exception:
                        continue
                    chunk = data.get("message", {}).get("content", "")
                    if chunk:
                        full.append(chunk)
                        yield chunk
                    if data.get("done"):
                        break
        except Exception as e:
            err = f"[Error Ollama: {e}]"
            full.append(err)
            yield err
        finally:
            complete = "".join(full)
            self._history.append({"role": "assistant", "content": complete})
            if len(self._history) > _MAX_HISTORY:
                self._history = self._history[-_MAX_HISTORY:]
            self._save_history()

    def embedding(self, text: str) -> Optional[list]:
        """Genera embedding del texto. Devuelve lista de floats o None si falla."""
        payload = json.dumps({
            "model":  self.model,
            "prompt": text[:1000],
        }).encode()
        req = urllib.request.Request(
            f"{self.base_url}/api/embeddings",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                return json.loads(r.read()).get("embedding")
        except Exception:
            return None

    def reset(self):
        self._history.clear()
        self._save_history()

    def set_system(self, prompt: str):
        self.system_prompt = prompt
