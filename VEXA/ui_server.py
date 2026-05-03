#!/usr/bin/env python3
"""
UI Server for VEXA
  HTTP  REST API → http://localhost:8765
  HTTPS REST API → https://<ip>:8443  (para microfono en celular)
  WebSocket      → ws://localhost:8766 / wss://<ip>:8767
  Static files   → sirve VEXA/ui/
"""

import asyncio
import http.server
import json
import os
import ssl
import threading
import urllib.parse
from datetime import datetime
from pathlib import Path
from typing import Set, Optional

try:
    import websockets
    HAS_WS = True
except ImportError:
    HAS_WS = False
    print("[UIServer] 'websockets' no encontrado — pip install websockets")

UI_DIR    = Path(__file__).parent / "ui"
SSL_DIR   = Path(__file__).parent / "ssl"
HTTP_PORT  = 8765
HTTPS_PORT = 8443
WS_PORT    = 8766
WSS_PORT   = 8767

def _local_ip() -> str:
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"

LOCAL_IP = _local_ip()

def _ssl_context() -> Optional[ssl.SSLContext]:
    cert = SSL_DIR / "cert.pem"
    key  = SSL_DIR / "key.pem"
    if not (cert.exists() and key.exists()):
        return None
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(str(cert), str(key))
    return ctx


# ── Shared state ──────────────────────────────────────────────────────
_ws_clients: Set = set()
_log_entries: list = []
_state_ref: Optional[object] = None
_voice_out_ref: Optional[object] = None
_command_queue: Optional[asyncio.Queue] = None
_interrupt_ref: Optional[object] = None


def _log(level: str, message: str):
    entry = {"timestamp": datetime.now().isoformat(), "level": level, "message": message}
    _log_entries.append(entry)
    if len(_log_entries) > 500:
        _log_entries.pop(0)


# ── HTTP handler ──────────────────────────────────────────────────────
class _Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI_DIR), **kwargs)

    def log_message(self, *args):
        pass

    def _json(self, data: dict, status: int = 200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/status":
            state_name = _state_ref.state_name if _state_ref else "IDLE"
            self._json({"status": "ok", "state": state_name,
                        "timestamp": datetime.now().isoformat()})
        elif path == "/log":
            self._json({"logs": _log_entries[-50:]})
        else:
            super().do_GET()

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        body = {}
        if length:
            try:
                body = json.loads(self.rfile.read(length))
            except Exception:
                self._json({"error": "JSON inválido"}, 400)
                return

        if path == "/speak":
            text = body.get("text", "")
            if text and _voice_out_ref:
                threading.Thread(target=_voice_out_ref.speak, args=(text,), daemon=True).start()
            self._json({"status": "ok"})

        elif path == "/state":
            new_state = body.get("state", "IDLE")
            if _command_queue:
                _command_queue.put_nowait(("state", new_state))
            self._json({"status": "ok", "state": new_state})

        elif path == "/command":
            command = body.get("command", "")
            if command and _command_queue:
                _command_queue.put_nowait(("command", command))
            self._json({"status": "ok", "command": command})

        elif path == "/interrupt":
            if _interrupt_ref:
                threading.Thread(target=_interrupt_ref, daemon=True).start()
            if _command_queue:
                _command_queue.put_nowait(("command", "para"))
            self._json({"status": "ok"})

        else:
            self._json({"error": "ruta no encontrada"}, 404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()


# ── WebSocket server ──────────────────────────────────────────────────
async def _ws_handler(websocket):
    _ws_clients.add(websocket)
    try:
        async for raw in websocket:
            try:
                msg = json.loads(raw)
                if msg.get("type") == "ping":
                    await websocket.send(json.dumps({"type": "pong"}))
                elif msg.get("type") == "get_status":
                    state = _state_ref.state_name if _state_ref else "IDLE"
                    await websocket.send(json.dumps({"type": "status", "state": state}))
            except Exception:
                pass
    except Exception:
        pass
    finally:
        _ws_clients.discard(websocket)


async def broadcast(message: dict):
    if not _ws_clients:
        return
    data = json.dumps(message)
    dead = set()
    for ws in list(_ws_clients):
        try:
            await ws.send(data)
        except Exception:
            dead.add(ws)
    _ws_clients.difference_update(dead)


# ── Public interface ──────────────────────────────────────────────────
class UIServer:
    def __init__(self, state_manager=None, voice_output=None, command_queue=None):
        global _state_ref, _voice_out_ref, _command_queue, _interrupt_ref
        _state_ref = state_manager
        _voice_out_ref = voice_output
        _command_queue = command_queue
        _interrupt_ref = voice_output.interrupt if voice_output else None
        self._http_thread: Optional[threading.Thread] = None
        self._httpd: Optional[http.server.HTTPServer] = None
        self._httpsd: Optional[http.server.HTTPServer] = None

    def start_http(self):
        self._httpd = http.server.HTTPServer(("0.0.0.0", HTTP_PORT), _Handler)
        self._http_thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)
        self._http_thread.start()
        print(f"[UIServer] HTTP  → http://localhost:{HTTP_PORT}")
        print(f"[UIServer] Red   → http://{LOCAL_IP}:{HTTP_PORT}")

        ssl_ctx = _ssl_context()
        if ssl_ctx:
            self._httpsd = http.server.HTTPServer(("0.0.0.0", HTTPS_PORT), _Handler)
            self._httpsd.socket = ssl_ctx.wrap_socket(self._httpsd.socket, server_side=True)
            t = threading.Thread(target=self._httpsd.serve_forever, daemon=True)
            t.start()
            print(f"[UIServer] HTTPS → https://{LOCAL_IP}:{HTTPS_PORT}/mobile.html  ← celular (micrófono)")
        else:
            print(f"[UIServer] HTTPS no disponible — sin SSL cert")

    async def start_ws(self):
        if not HAS_WS:
            return
        import websockets
        self._ws_server = await websockets.serve(_ws_handler, "0.0.0.0", WS_PORT)
        print(f"[UIServer] WS   → ws://localhost:{WS_PORT}")

        ssl_ctx = _ssl_context()
        if ssl_ctx:
            self._wss_server = await websockets.serve(_ws_handler, "0.0.0.0", WSS_PORT, ssl=ssl_ctx)
            print(f"[UIServer] WSS  → wss://{LOCAL_IP}:{WSS_PORT}  ← celular")

    def stop(self):
        if self._httpd:
            self._httpd.shutdown()
        if self._httpsd:
            self._httpsd.shutdown()

    @staticmethod
    async def broadcast(message: dict):
        await broadcast(message)
