#!/usr/bin/env python3
# Detector de Duplicados RAG — Identifica notas muy similares
import json
import os
import sys

AI_ROOT = "/home/mash/Opencode/Obsidian/AI-Memory"
INDEX_FILE = AI_ROOT + "/.rag/index.json"

def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, 'r') as f:
            return json.load(f)
    return {"documentos": {}}

def detectar():
    index = load_index()
    docs = index["documentos"]
    duplicados = []
    
    # Simple comparación por hash
    hashes = {}
    for ruta, doc in docs.items():
        h = doc.get("hash")
        if h in hashes:
            duplicados.append((ruta, hashes[h]))
        else:
            hashes[h] = ruta
            
    if duplicados:
        print("=== Posibles duplicados detectados ===")
        for d, original in duplicados:
            print(f"[!] {d} es muy similar a {original}")
    else:
        print("[OK] No se detectaron duplicados")

if __name__ == '__main__':
    detectar()