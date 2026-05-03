#!/usr/bin/env python3
# Indexador RAG Incremental — Sin dependencias externas
# Usage: python3 indexador.py [index|status|clear]

import hashlib
import json
import os
import re
import sys
import urllib.request
from datetime import datetime

AI_ROOT    = "/home/mash/Opencode/Obsidian/AI-Memory"
INDEX_FILE = AI_ROOT + "/.rag/index.json"

_STOP = {
    "el", "la", "los", "las", "de", "en", "a", "un", "una", "y", "o",
    "que", "es", "se", "del", "al", "con", "por", "para", "no", "si",
    "lo", "le", "me", "mi", "tu", "su", "yo", "te", "ha", "he", "hay",
    "qué", "como", "cómo", "cuál", "cual", "cuándo", "cuando", "este",
    "esta", "son", "sus", "pero", "más", "mas", "fue", "ser", "era",
    "the", "and", "or", "of", "to", "in", "is", "it", "at", "be", "as", "an",
}


def clean_markdown(text: str) -> str:
    text = re.sub(r"```[\s\S]*?```", " ", text)        # code blocks
    text = re.sub(r"`[^`\n]*`", " ", text)             # inline code
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)  # links → label
    text = re.sub(r"!\[[^\]]*\]\([^\)]+\)", " ", text) # images
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.M) # headers
    text = re.sub(r"[*_~`>|\\]", " ", text)            # bold/italic/etc
    text = re.sub(r"^\s*[-+*]\s+", "", text, flags=re.M)   # bullets
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def tokenize(text: str) -> list:
    clean = clean_markdown(text)
    words = re.sub(r"[^\w\s]", "", clean.lower()).split()
    return list({w for w in words if w not in _STOP and len(w) > 2})


OLLAMA_URL  = "http://127.0.0.1:11434"
EMBED_MODEL = "llama3.2:1b"


def _get_embedding(text: str):
    """Llama a Ollama /api/embeddings. Devuelve lista de floats o None."""
    try:
        payload = json.dumps({"model": EMBED_MODEL, "prompt": text[:800]}).encode()
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/embeddings",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read()).get("embedding")
    except Exception:
        return None


def _ollama_available() -> bool:
    try:
        urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=2)
        return True
    except Exception:
        return False


def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"documentos": {}, "metadatos": {}}


def save_index(index):
    os.makedirs(os.path.dirname(INDEX_FILE), exist_ok=True)
    with open(INDEX_FILE, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)


def indexar_notas(with_embeddings: bool = None):
    """Indexa notas incrementalmente. Con embeddings si Ollama está disponible."""
    index      = load_index()
    actualizados = 0

    if with_embeddings is None:
        with_embeddings = _ollama_available()

    if with_embeddings:
        print("[INFO] Embeddings habilitados (Ollama disponible)")

    for root, dirs, files in os.walk(AI_ROOT):
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        for fname in files:
            if not fname.endswith(".md"):
                continue

            filepath = os.path.join(root, fname)
            ruta     = os.path.relpath(filepath, AI_ROOT)
            mtime    = os.path.getmtime(filepath)
            existing = index["documentos"].get(ruta, {})

            # Saltar si el archivo no cambió Y ya tiene embedding (si aplica)
            if existing.get("mtime") == mtime:
                if not with_embeddings or existing.get("embedding"):
                    continue

            try:
                raw = open(filepath, encoding="utf-8").read()
            except Exception as e:
                print(f"[ERROR] {ruta}: {e}")
                continue

            titulo   = os.path.splitext(fname)[0]
            limpio   = clean_markdown(raw)
            palabras = tokenize(raw)
            digest   = hashlib.md5(raw[:1000].encode()).hexdigest()

            entry = {
                "titulo":    titulo,
                "contenido": limpio[:2000],
                "palabras":  palabras[:400],
                "hash":      digest,
                "mtime":     mtime,
            }

            if with_embeddings:
                vec = _get_embedding(limpio[:800])
                if vec:
                    entry["embedding"] = vec

            index["documentos"][ruta] = entry
            actualizados += 1
            emb_tag = " +emb" if entry.get("embedding") else ""
            print(f"[OK] {ruta}  ({len(palabras)} términos{emb_tag})")

    index["metadatos"]["ultimo_indexado"]  = datetime.now().isoformat()
    index["metadatos"]["total_documentos"] = len(index["documentos"])
    save_index(index)
    return actualizados


def needs_reindex() -> bool:
    """True si hay archivos .md nuevos o modificados desde el último índice."""
    index = load_index()
    for root, dirs, files in os.walk(AI_ROOT):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for fname in files:
            if not fname.endswith(".md"):
                continue
            filepath = os.path.join(root, fname)
            ruta     = os.path.relpath(filepath, AI_ROOT)
            mtime    = os.path.getmtime(filepath)
            doc      = index["documentos"].get(ruta)
            if doc is None or doc.get("mtime") != mtime:
                return True
    return False


def status():
    index  = load_index()
    ultimo = index["metadatos"].get("ultimo_indexado", "Nunca")
    total  = index["metadatos"].get("total_documentos", 0)
    stale  = needs_reindex()
    print("=== Estado del Índice RAG ===")
    print(f"Documentos indexados : {total}")
    print(f"Último indexado      : {ultimo}")
    print(f"Necesita re-indexar  : {'SÍ' if stale else 'No'}")
    print(f"Índice               : {INDEX_FILE}")


def clear():
    index = load_index()
    index["documentos"] = {}
    index["metadatos"]  = {}
    save_index(index)
    print("[OK] Índice limpiado")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "index":
        print("[INFO] Indexando notas...")
        n = indexar_notas()
        print(f"[OK] {n} documentos actualizados")
    elif cmd == "check":
        print("re-index needed" if needs_reindex() else "up-to-date")
    elif cmd == "status":
        status()
    elif cmd == "clear":
        clear()
    else:
        print("Usage: indexador.py [index|status|clear|check]")
