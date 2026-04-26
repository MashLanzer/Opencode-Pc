#!/usr/bin/env python3
# Indexador RAG Incremental — Sin dependencias externas
# Usage: python3 indexador.py [index|status|clear]

import os
import sys
import json
import hashlib
from datetime import datetime

AI_ROOT = "/home/mash/Opencode/Obsidian/AI-Memory"
INDEX_FILE = AI_ROOT + "/.rag/index.json"

def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, 'r') as f:
            return json.load(f)
    return {"documentos": {}, "metadatos": {}}

def save_index(index):
    os.makedirs(os.path.dirname(INDEX_FILE), exist_ok=True)
    with open(INDEX_FILE, 'w') as f:
        json.dump(index, f, indent=2)

def get_hash(texto):
    texto = texto.lower()[:1000]
    return hashlib.md5(texto.encode()).hexdigest()

def indexar_notas():
    index = load_index()
    extensiones = ['.md']
    total = 0
    actualizados = 0
    
    for root, dirs, files in os.walk(AI_ROOT):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        
        for file in files:
            if any(file.endswith(ext) for ext in extensiones):
                filepath = os.path.join(root, file)
                ruta = os.path.relpath(filepath, AI_ROOT)
                
                # Obtener tiempo de modificación actual
                mtime = os.path.getmtime(filepath)
                
                # Verificar si ya existe y si ha cambiado
                if ruta in index["documentos"] and index["documentos"][ruta].get("mtime") == mtime:
                    continue # No ha cambiado, saltar
                
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        contenido = f.read()
                    
                    contenido_limpio = contenido[:3000]
                    hash_embed = get_hash(contenido_limpio)
                    
                    index["documentos"][ruta] = {
                        "contenido": contenido_limpio,
                        "hash": hash_embed,
                        "mtime": mtime,
                        "palabras": list(set(contenido_limpio.lower().split()[:200]))
                    }
                    total += 1
                    actualizados += 1
                    print(f"[OK] Indexado/Actualizado: {ruta}")
                except Exception as e:
                    print(f"[ERROR] {ruta}: {e}")
    
    index["metadatos"]["ultimo_indexado"] = datetime.now().isoformat()
    index["metadatos"]["total_documentos"] = str(len(index["documentos"]))
    
    save_index(index)
    return actualizados

def status():
    index = load_index()
    ultimo = index["metadatos"].get("ultimo_indexado", "Nunca")
    total = index["metadatos"].get("total_documentos", "0")
    
    print("=== Estado del Índice RAG ===")
    print(f"Documentos indexados: {total}")
    print(f"Último indexado: {ultimo}")
    print(f"Índice: {INDEX_FILE}")

def clear():
    index = load_index()
    index["documentos"] = {}
    index["metadatos"] = {}
    save_index(index)
    print("[OK] Índice limpiado")

if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'status'
    
    if cmd == 'index':
        print("[INFO] Indexando notas incrementalmente...")
        actualizados = indexar_notas()
        print(f"[OK] {actualizados} documentos procesados")
    elif cmd == 'status':
        status()
    elif cmd == 'clear':
        clear()
    else:
        print("Usage: indexador.py [index|status|clear]")