#!/usr/bin/env python3
"""
VEXA HUD — Widget flotante siempre visible en el escritorio.
Muestra estado de VEXA, última respuesta, e input de comandos.
Sin dependencias externas — solo Python stdlib + tkinter.

Uso: python3 VEXA/hud.py [--corner top-right|top-left|bottom-right|bottom-left]
"""

import json
import socket
import sys
import threading
import tkinter as tk
import urllib.request
from pathlib import Path

API_URL = "http://localhost:8765"


def _local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"


def _make_qr_image(url: str, size: int = 180):
    """Genera imagen QR como PhotoImage de Tk. Devuelve None si falla."""
    try:
        import qrcode
        qr = qrcode.QRCode(box_size=4, border=2)
        qr.add_data(url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        # Convertir a PhotoImage via bytes PPM
        import io
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        buf.seek(0)
        try:
            from PIL import Image, ImageTk
            pil_img = Image.open(buf).resize((size, size), Image.NEAREST)
            return ImageTk.PhotoImage(pil_img)
        except ImportError:
            return None
    except Exception:
        return None

STATE_COLORS = {
    "IDLE":       "#44aaff",
    "LISTENING":  "#44ff88",
    "THINKING":   "#ffaa44",
    "SPEAKING":   "#cc44ff",
    "PC_CONTROL": "#4488ff",
    "AGENT":      "#ff8844",
}

STATE_LABELS = {
    "IDLE":       "en espera",
    "LISTENING":  "escuchando...",
    "THINKING":   "pensando...",
    "SPEAKING":   "respondiendo...",
    "PC_CONTROL": "modo PC",
    "AGENT":      "modo agente",
}

CORNER = "top-right"


def _api(endpoint: str, method="GET", data: dict = None):
    try:
        payload = json.dumps(data).encode() if data else None
        req = urllib.request.Request(
            f"{API_URL}{endpoint}",
            data=payload,
            headers={"Content-Type": "application/json"} if payload else {},
            method=method,
        )
        with urllib.request.urlopen(req, timeout=2) as r:
            return json.loads(r.read())
    except Exception:
        return None


class VexaHUD:
    POLL_MS   = 2000
    WIDTH     = 320
    HEIGHT    = 110
    MARGIN    = 12

    def __init__(self, corner: str = "top-right"):
        self.corner   = corner
        self._state   = "?"
        self._running = False

        self.root = tk.Tk()
        self.root.title("VEXA HUD")
        self.root.overrideredirect(True)          # sin barra de título
        self.root.attributes("-topmost", True)    # siempre encima
        self.root.attributes("-alpha", 0.88)
        self.root.configure(bg="#0a0a1a")
        self.root.resizable(False, False)

        self._build_ui()
        self._position()
        self._bind_drag()

        # Poll VEXA API en hilo separado
        self._poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._poll_thread.start()

    # ── UI ────────────────────────────────────────────────────────────
    def _build_ui(self):
        BG   = "#0a0a1a"
        DIM  = "#334"
        FONT = ("Courier", 9)

        # Borde superior con color de estado
        self._state_bar = tk.Frame(self.root, bg="#44aaff", height=3)
        self._state_bar.pack(fill=tk.X)

        body = tk.Frame(self.root, bg=BG, padx=8, pady=6)
        body.pack(fill=tk.BOTH, expand=True)

        # Fila 1: logo + estado
        row1 = tk.Frame(body, bg=BG)
        row1.pack(fill=tk.X)

        self._logo = tk.Label(row1, text="VEXA", bg=BG, fg="#44aaff",
                              font=("Courier", 11, "bold"))
        self._logo.pack(side=tk.LEFT)

        self._state_lbl = tk.Label(row1, text="conectando...", bg=BG,
                                    fg=DIM, font=FONT)
        self._state_lbl.pack(side=tk.LEFT, padx=(8, 0))

        btn_qr = tk.Label(row1, text="QR", bg=BG, fg=DIM,
                           font=("Courier", 9), cursor="hand2")
        btn_qr.pack(side=tk.RIGHT, padx=(0, 6))
        btn_qr.bind("<Button-1>", lambda _: self._show_qr())

        btn_close = tk.Label(row1, text="✕", bg=BG, fg=DIM,
                              font=("Courier", 10), cursor="hand2")
        btn_close.pack(side=tk.RIGHT)
        btn_close.bind("<Button-1>", lambda _: self.root.destroy())

        # Fila 2: última respuesta
        self._response = tk.Label(
            body, text="", bg=BG, fg="#8899bb",
            font=FONT, wraplength=self.WIDTH - 24,
            anchor="w", justify="left",
        )
        self._response.pack(fill=tk.X, pady=(3, 5))

        # Fila 3: input de comando
        inp_frame = tk.Frame(body, bg=DIM, bd=0)
        inp_frame.pack(fill=tk.X)

        self._cmd_var = tk.StringVar()
        self._cmd_entry = tk.Entry(
            inp_frame, textvariable=self._cmd_var,
            bg="#111122", fg="#ccddff", insertbackground="#44aaff",
            font=FONT, bd=0, relief=tk.FLAT,
        )
        self._cmd_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=4, padx=(4, 0))
        self._cmd_entry.bind("<Return>", self._send_command)

        btn_send = tk.Label(inp_frame, text="↵", bg="#111122",
                             fg="#44aaff", font=FONT, cursor="hand2",
                             padx=6, pady=4)
        btn_send.pack(side=tk.RIGHT)
        btn_send.bind("<Button-1>", self._send_command)

    def _position(self):
        self.root.update_idletasks()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        w, h = self.WIDTH, self.HEIGHT
        m = self.MARGIN
        positions = {
            "top-right":     (sw - w - m, m),
            "top-left":      (m, m),
            "bottom-right":  (sw - w - m, sh - h - m - 48),
            "bottom-left":   (m, sh - h - m - 48),
        }
        x, y = positions.get(self.corner, positions["top-right"])
        self.root.geometry(f"{w}x{h}+{x}+{y}")

    def _bind_drag(self):
        """Permite arrastrar el HUD con el mouse."""
        self._drag_x = 0
        self._drag_y = 0
        self.root.bind("<ButtonPress-1>", self._drag_start)
        self.root.bind("<B1-Motion>", self._drag_move)

    def _drag_start(self, e):
        self._drag_x = e.x_root - self.root.winfo_x()
        self._drag_y = e.y_root - self.root.winfo_y()

    def _drag_move(self, e):
        nx = e.x_root - self._drag_x
        ny = e.y_root - self._drag_y
        self.root.geometry(f"+{nx}+{ny}")

    # ── Update UI ─────────────────────────────────────────────────────
    def _update_state(self, state: str, last_msg: str = ""):
        color = STATE_COLORS.get(state, "#556")
        label = STATE_LABELS.get(state, state.lower())

        self._state_bar.configure(bg=color)
        self._logo.configure(fg=color)
        self._state_lbl.configure(text=label, fg=color)

        if last_msg:
            short = last_msg[:90] + "…" if len(last_msg) > 90 else last_msg
            self._response.configure(text=short)

        self._state = state

    # ── Poll API ──────────────────────────────────────────────────────
    def _poll_loop(self):
        import time
        while True:
            data = _api("/status")
            if data:
                state = data.get("state", "IDLE")
                self.root.after(0, self._update_state, state)
            else:
                self.root.after(0, self._update_state, "?",
                                "VEXA offline — ia vexa start")
            time.sleep(self.POLL_MS / 1000)

    # ── Send command ──────────────────────────────────────────────────
    def _send_command(self, _event=None):
        cmd = self._cmd_var.get().strip()
        if not cmd:
            return
        self._cmd_var.set("")
        threading.Thread(
            target=lambda: _api("/command", "POST", {"command": cmd}),
            daemon=True,
        ).start()

    def _show_qr(self):
        """Abre ventana con QR de acceso móvil."""
        ip  = _local_ip()
        url = f"http://{ip}:8765/mobile.html"

        win = tk.Toplevel(self.root)
        win.title("VEXA — Acceso Móvil")
        win.configure(bg="#0a0a1a")
        win.resizable(False, False)
        win.attributes("-topmost", True)

        tk.Label(win, text="Escaneá desde tu teléfono",
                 bg="#0a0a1a", fg="#44aaff",
                 font=("Courier", 10, "bold")).pack(pady=(12, 4))

        qr_img = _make_qr_image(url, size=200)
        if qr_img:
            lbl = tk.Label(win, image=qr_img, bg="white", relief="flat")
            lbl.image = qr_img  # evitar garbage collection
            lbl.pack(padx=16, pady=8)
        else:
            tk.Label(win, text="[instala Pillow para ver el QR]",
                     bg="#0a0a1a", fg="#556").pack(padx=16, pady=8)

        tk.Label(win, text=url, bg="#0a0a1a", fg="#8899bb",
                 font=("Courier", 8)).pack(pady=(0, 8))

        tk.Button(win, text="Cerrar", command=win.destroy,
                  bg="#111122", fg="#44aaff",
                  font=("Courier", 9), relief="flat",
                  padx=12, pady=4).pack(pady=(0, 12))

    def run(self):
        self.root.mainloop()


# ── Entry point ───────────────────────────────────────────────────────
if __name__ == "__main__":
    corner = "top-right"
    if "--corner" in sys.argv:
        idx = sys.argv.index("--corner")
        if idx + 1 < len(sys.argv):
            corner = sys.argv[idx + 1]

    hud = VexaHUD(corner=corner)
    hud.run()
