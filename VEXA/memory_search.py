#!/usr/bin/env python3
"""RAG memory search for VEXA — keyword + embedding semántico via Ollama."""

import json
import math
import re
import urllib.request
from pathlib import Path
from typing import Optional

INDEX_FILE  = Path("/home/mash/Opencode/Obsidian/AI-Memory/.rag/index.json")
OLLAMA_URL  = "http://127.0.0.1:11434"
EMBED_MODEL = "llama3.2:1b"

_STOP = {
    "el", "la", "los", "las", "de", "en", "a", "un", "una", "y", "o",
    "que", "es", "se", "del", "al", "con", "por", "para", "no", "si",
    "lo", "le", "me", "mi", "tu", "su", "yo", "te", "ha", "he", "hay",
    "qué", "como", "cómo", "cuál", "cual", "cuándo", "cuando", "este",
    "esta", "son", "sus", "pero", "más", "mas", "fue", "ser", "era",
}


def _cosine(a: list, b: list) -> float:
    dot  = sum(x * y for x, y in zip(a, b))
    na   = math.sqrt(sum(x * x for x in a))
    nb   = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb) if na and nb else 0.0


def _get_embedding(text: str) -> Optional[list]:
    payload = json.dumps({"model": EMBED_MODEL, "prompt": text[:800]}).encode()
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/embeddings",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read()).get("embedding")
    except Exception:
        return None


class MemorySearch:
    def __init__(self, index_path: Path = INDEX_FILE):
        self.index_path = index_path
        self._index: Optional[dict] = None

    def _load(self):
        if self._index is not None:
            return
        if not self.index_path.exists():
            self._index = {}
            return
        try:
            raw = json.load(open(self.index_path, encoding="utf-8"))
            if "documentos" in raw and isinstance(raw["documentos"], dict):
                self._index = raw["documentos"]
            else:
                self._index = raw
        except Exception:
            self._index = {}

    def reload(self):
        self._index = None
        self._load()

    # ── Búsqueda por keywords ─────────────────────────────────────────
    def _keyword_search(self, query: str, top_k: int = 3) -> list[dict]:
        self._load()
        if not self._index:
            return []
        words = {w for w in re.sub(r"[^\w\s]", "", query.lower()).split()
                 if w not in _STOP and len(w) > 2}
        if not words:
            return []

        results = []
        for doc_id, doc in self._index.items():
            doc_words = {re.sub(r"[^\w]", "", w).lower()
                         for w in doc.get("palabras", []) if len(w) > 2}
            score = len(words & doc_words)
            if score > 0:
                results.append({
                    "score":     score,
                    "doc_id":    doc_id,
                    "titulo":    doc.get("titulo", Path(doc_id).stem),
                    "contenido": doc.get("contenido", "")[:500],
                })
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:top_k]

    # ── Búsqueda semántica via embeddings Ollama ──────────────────────
    def _semantic_search(self, query: str, top_k: int = 2) -> list[dict]:
        self._load()
        if not self._index:
            return []

        query_vec = _get_embedding(query)
        if not query_vec:
            return []

        results = []
        for doc_id, doc in self._index.items():
            doc_vec = doc.get("embedding")
            if not doc_vec:
                continue
            sim = _cosine(query_vec, doc_vec)
            if sim > 0.5:
                results.append({
                    "score":     round(sim, 3),
                    "doc_id":    doc_id,
                    "titulo":    doc.get("titulo", Path(doc_id).stem),
                    "contenido": doc.get("contenido", "")[:500],
                })
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:top_k]

    # ── Búsqueda combinada (híbrida) ─────────────────────────────────
    def search(self, query: str, top_k: int = 2) -> list[dict]:
        """Combina keywords + embeddings semánticos. Filtra duplicados por doc_id."""
        kw = self._keyword_search(query, top_k)

        # Solo llamar embeddings si keyword search devuelve resultados débiles
        use_semantic = not kw or kw[0]["score"] < 2
        sem = self._semantic_search(query, top_k) if use_semantic else []

        # Merge, deduplicar por doc_id, priorizar semántico si kw fue débil
        seen: set = set()
        merged = []
        for r in (sem + kw):
            if r["doc_id"] not in seen:
                seen.add(r["doc_id"])
                merged.append(r)
        return merged[:top_k]

    def build_context(self, query: str) -> str:
        results = self.search(query)
        if not results:
            return ""
        parts = ["[Contexto de tu memoria personal:]"]
        for r in results:
            parts.append(f"  • {r['titulo']}: {r['contenido']}")
        return "\n".join(parts)

    @property
    def is_available(self) -> bool:
        return self.index_path.exists()
