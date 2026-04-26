#!/usr/bin/env python3
# Buscador RAG — Sin dependencias externas
# Usage: python3 buscador.py "tu pregunta" [top-k]

import os
import sys
import json
import hashlib

AI_ROOT = "/home/mash/Opencode/Obsidian/AI-Memory"
INDEX_FILE = AI_ROOT + "/.rag/index.json"
TOP_K = int(sys.argv[2]) if len(sys.argv) > 2 else 3

def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, 'r') as f:
            return json.load(f)
    return {"documentos": {}, "metadatos": {}}

def buscar(query, top_k=3):
    index = load_index()
    query_palabras = set(query.lower().split())
    resultados = []
    
    for ruta, doc in index["documentos"].items():
        doc_palabras = set(doc.get("palabras", []))
        
        interseccion = len(query_palabras & doc_palabras)
        
        if interseccion > 0:
            resultados.append((ruta, doc.get("contenido", "")[:200], interseccion))
    
    resultados.sort(key=lambda x: x[2], reverse=True)
    return resultados[:top_k]

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 buscador.py \"tu pregunta\" [top-k]")
        sys.exit(1)
    
    query = sys.argv[1]
    resultados = buscar(query, TOP_K)
    
    print(f"=== Resultados para: {query} ===\n")
    
    if not resultados:
        print("[INFO] No hay resultados. Intenta indexar primero:")
        print("  python3 indexador.py index")
    else:
        for i, (ruta, contenido, score) in enumerate(resultados, 1):
            print(f"{i}. [{score}] {ruta}")
            print(f"   {contenido[:150]}...")
            print()