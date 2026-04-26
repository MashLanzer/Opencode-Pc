#!/usr/bin/env python3
# API RAG (JSON-based) — Sin dependencias externas
# Usage: python3 rag-api.py [port]

import json
import os
import sys
import http.server
import socketserver
from urllib.parse import urlparse, parse_qs
import subprocess

AI_ROOT = "/home/mash/Opencode/Obsidian/AI-Memory"
INDEX_FILE = AI_ROOT + "/.rag/index.json"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5001

def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, 'r') as f:
            return json.load(f)
    return {"documentos": {}, "metadatos": {}}

def buscar_query(query, top_k=3):
    index = load_index()
    query_palabras = set(query.lower().split())
    resultados = []
    
    for ruta, doc in index["documentos"].items():
        doc_palabras = set(doc.get("palabras", []))
        interseccion = len(query_palabras & doc_palabras)
        
        if interseccion > 0:
            resultados.append((ruta, doc.get("contenido", ""), interseccion))
    
    resultados.sort(key=lambda x: x[2], reverse=True)
    return resultados[:top_k]

class Handler(http.server.BaseHTTPRequestHandler):
    def responder(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        path = urlparse(self.path).path
        query = parse_qs(urlparse(self.path).query)
        
        if path == '/rag/status':
            self.responder({'status': 'ok'})
        elif path == '/rag/search':
            q = query.get('q', [''])[0]
            resultados = buscar_query(q)
            self.responder({
                'resultados': [{'ruta': r, 'score': s} for r, c, s in resultados]
            })
        else:
            self.responder({'error': 'no encontrada'}, 404)
    
    def do_POST(self):
        if self.path == '/rag/query':
            largo = int(self.headers.get('Content-Length', 0))
            data = json.loads(self.rfile.read(largo))
            query = data.get('q', '')
            
            resultados = buscar_query(query)
            contexto = '\n\n'.join([f"=== {r} ===\n{c[:500]}" for r, c, s in resultados])
            
            prompt = f"Contexto:\n{contexto}\n\nPregunta: {query}\n\nRespuesta:"
            
            # Llamar a Ollama
            proc = subprocess.run(['~/.local/bin/ollama', 'run', 'llama3.2:1b'],
                                 input=prompt, capture_output=True, text=True)
            
            self.responder({'respuesta': proc.stdout})
        else:
            self.responder({'error': 'no encontrada'}, 404)

if __name__ == '__main__':
    print(f"RAG API corriendo en http://localhost:{PORT}")
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()