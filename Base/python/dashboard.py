#!/usr/bin/env python3
# Dashboard Web — Interfaz para ver estado del sistema
import html
import http.server
import socketserver
import subprocess

PORT = 8080
BASE_DIR = "/home/mash/Opencode/Base"
LOG_FILE = "/home/mash/Opencode/Base/logs/auto-agente.log"

def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    return html.escape(result.stdout + result.stderr)

class DashboardHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # silence request logs

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()

        status = run([f"{BASE_DIR}/scripts/ia.sh", "status"])
        logs = run(["tail", "-n", "20", LOG_FILE])

        page = f"""<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>IA Dashboard</title></head>
<body style="font-family:sans-serif;padding:20px;">
    <h1>Sistema de IA</h1>
    <h3>Estado:</h3><pre>{status}</pre>
    <h3>Últimos logs:</h3><pre>{logs}</pre>
    <script>setTimeout(()=>location.reload(),5000)</script>
</body>
</html>"""
        self.wfile.write(page.encode())

if __name__ == '__main__':
    with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
        print(f"Dashboard en http://localhost:{PORT}")
        httpd.serve_forever()