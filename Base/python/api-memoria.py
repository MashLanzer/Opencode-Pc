#!/usr/bin/env python3
# API REST Simple para Memoria IA (sin dependencias externas)
# Usage: python3 api-memoria.py [puerto]

import http.server
import json
import os
import socketserver
import subprocess
from datetime import datetime
from urllib.parse import urlparse

AI_ROOT = os.path.expanduser("/home/mash/Opencode/Obsidian/AI-Memory")
PORT = int(os.environ.get("PORT", 5000))

class Handler(http.server.BaseHTTPRequestHandler):
    def leer(self, ruta):
        try:
            with open(f"{AI_ROOT}/{ruta}", 'r') as f:
                return f.read()[:1000]
        except:
            return None
    
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == '/api/status':
            self.responder({'status': 'ok', 'timestamp': datetime.now().isoformat()})
        elif path == '/api/memoria':
            self.responder({'contenido': self.leer('MEMORIA-PRINCIPAL.md')})
        elif path == '/api/tareas':
            self.responder({'contenido': self.leer('tareas-pendientes.md')})
        elif path == '/api/proyectos':
            self.responder({'contenido': self.leer('Proyectos/_indice-proyectos.md')})
        elif path == '/api/salud':
            try:
                d = subprocess.run(
                    ["df", "/"], capture_output=True, text=True
                ).stdout.splitlines()[1].split()[4].rstrip('%')
                mem = subprocess.run(
                    ["free"], capture_output=True, text=True
                ).stdout.splitlines()[1].split()
                r = str(int(int(mem[2]) / int(mem[1]) * 100))
                self.responder({'disco': d, 'ram': r})
            except Exception as e:
                self.responder({'error': str(e)}, 500)
        else:
            self.responder({'error': 'ruta no encontrada'}, 404)
    
    def responder(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == '__main__':
    print(f"API corriendo en http://localhost:{PORT}")
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()