#!/usr/bin/env python3
"""Wake word detection for VEXA."""

import re

# Patrones del wake word + variantes que Whisper suele transcribir
_PATTERNS = [
    r"\b(?:oye|hey|hola)\s+vexa\b",
    r"\bvexa\b",
    r"\bbeka\b",    # mishearing común de Whisper
    r"\bbeca\b",
    r"\bweka\b",
    r"\bvexa\b",
]

_COMPILED = [re.compile(p, re.I) for p in _PATTERNS]


def contains_wake_word(text: str) -> bool:
    """Devuelve True si el texto contiene el wake word."""
    return any(p.search(text) for p in _COMPILED)


def strip_wake_word(text: str) -> str:
    """Elimina el wake word y devuelve solo el comando."""
    result = text
    for p in _COMPILED:
        result = p.sub("", result)
    # Limpiar separadores sobrantes al inicio
    result = re.sub(r"^[\s,.:;!?]+", "", result)
    return result.strip()
