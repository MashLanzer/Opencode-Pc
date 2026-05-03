#!/usr/bin/env python3
"""OpenCode bridge for VEXA — persistent Claude Code CLI subprocess."""

import queue
import re
import subprocess
import threading
import time
from typing import Optional

ANSI = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")


class OpenCodeBridge:
    def __init__(self, working_dir: str = "/home/mash/Opencode"):
        self.working_dir = working_dir
        self._proc: Optional[subprocess.Popen] = None
        self._queue: queue.Queue = queue.Queue()
        self._reader: Optional[threading.Thread] = None
        self._active = False

    def start(self) -> bool:
        """Launch Claude Code CLI as a persistent subprocess."""
        try:
            self._proc = subprocess.Popen(
                ["claude", "--no-color"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=self.working_dir,
                bufsize=1,
            )
            self._active = True
            self._reader = threading.Thread(target=self._read_loop, daemon=True)
            self._reader.start()
            print("[OpenCode] Claude Code iniciado")
            return True
        except FileNotFoundError:
            print("[OpenCode] Comando 'claude' no encontrado en PATH")
            return False
        except Exception as e:
            print(f"[OpenCode] Error: {e}")
            return False

    def _read_loop(self):
        for line in iter(self._proc.stdout.readline, ""):
            clean = ANSI.sub("", line).strip()
            if clean:
                self._queue.put(clean)
        self._active = False

    def send(self, command: str, timeout: float = 8.0) -> str:
        """Send a command and collect the response."""
        if not self._active or not self._proc:
            return "[Error: OpenCode no está corriendo]"

        # Flush pending output
        while not self._queue.empty():
            self._queue.get_nowait()

        self._proc.stdin.write(command + "\n")
        self._proc.stdin.flush()

        lines = []
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                line = self._queue.get(timeout=0.3)
                lines.append(line)
            except queue.Empty:
                if lines:
                    break

        return "\n".join(lines) or "[Sin respuesta]"

    def stop(self):
        self._active = False
        if self._proc:
            try:
                self._proc.terminate()
                self._proc.wait(timeout=5)
            except Exception:
                self._proc.kill()
            self._proc = None

    @property
    def is_running(self) -> bool:
        return self._active
