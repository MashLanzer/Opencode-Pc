#!/usr/bin/env python3
"""Command library for VEXA — voice intent detection in Spanish."""

import re
from typing import Optional, Tuple

# Map of intent → list of regex patterns
COMMANDS: dict[str, list[str]] = {
    "recordatorio": [
        r"recuérdame",
        r"recuerdame",
        r"pon un recordatorio",
        r"ponme (?:un )?recordatorio",
        r"avísame",
        r"avisame",
        r"en \d+ (?:minutos?|horas?) (?:que )?",
    ],
    "toggle_wake": [
        r"(?:activa|desactiva) (?:el )?wake word",
        r"(?:activa|desactiva) (?:la )?escucha continua",
        r"modo siempre escuchando",
    ],
    "modo_agente": [
        r"modo agente",
        r"activa(?: el)? agente",
        r"ejecuta(?: el)? agente",
    ],
    "modo_pc": [
        r"modo (?:pc|control|terminal)",
        r"controla(?: el)? (?:pc|computadora|sistema)",
        r"abre (?:una? )?terminal",
        r"modo control",
    ],
    "modo_chat": [
        r"modo chat",
        r"quiero hablar",
        r"conversemos",
        r"modo normal",
    ],
    "parar": [
        r"(?:para|detén|detente|cancela|stop)",
        r"suficiente",
        r"silencio",
        r"cállate",
    ],
    "estado": [
        r"(?:cómo|como) (?:estás|estas)",
        r"estado del sistema",
        r"status",
        r"¿qué estás haciendo",
    ],
    "salir": [
        r"(?:adiós|adios|hasta luego|cierra vexa|apágate|apegate|exit|salir)",
        r"apaga(?: el)? sistema",
    ],
    "volumen_subir": [
        r"(?:sube|aumenta|más alto)(?: el)? volumen",
        r"más (?:alto|volumen)",
    ],
    "volumen_bajar": [
        r"(?:baja|reduce|menos)(?: el)? volumen",
        r"más (?:bajo|silencioso)",
    ],
    "limpiar_historial": [
        r"(?:limpia|borra|olvida)(?: el)? (?:historial|contexto|conversación)",
        r"empieza de cero",
        r"nueva conversación",
    ],
    "ayuda": [
        r"(?:ayuda|help|qué puedes hacer|que puedes hacer)",
        r"comandos disponibles",
    ],
    "multimodal": [
        r"qué (?:dice|hay|ves|tienes) en (?:la |mi )?pantalla",
        r"que (?:dice|hay|ves|tienes) en (?:la |mi )?pantalla",
        r"analiza(?: la)? pantalla",
        r"lee(?: la)? pantalla",
        r"captura(?: de)? pantalla",
        r"screenshot",
        r"qué estoy (?:viendo|mirando)",
        r"que estoy (?:viendo|mirando)",
        r"(?:describí|describe|describeme|describeme|mirá|mira)(?: la)? pantalla",
        r"qué (?:ves|hay|pasa) ahí",
        r"que (?:ves|hay|pasa) ahí",
        r"(?:leer?|analiza)(?: el)? (?:error|mensaje|texto)(?: de la pantalla)?",
        r"qué dice (?:ahí|aquí|eso)",
    ],
    "guardar_nota": [
        r"(?:guarda|anota|recuerda|apunta)(?: que)?[:\s]",
        r"(?:nota|apunte)[:\s]",
        r"no (?:te )?olvides(?: que)?[:\s]",
    ],
    "historial": [
        r"(?:resumí|resumi|resume|qué hicimos|que hicimos|qué hablamos|que hablamos)",
        r"(?:resumen|resum[ée]n) de (?:ayer|hoy|la semana|esta semana|anoche)",
        r"(?:qué|que) (?:estuvimos|estaba|estabas) (?:haciendo|trabajando|hablando)",
        r"(?:recordá|recorda|recordame) (?:qué|que) (?:hice|hablamos|trabajamos) (?:ayer|hoy)",
        r"(?:qué|que) (?:pasó|paso) ayer",
    ],
    "aprender": [
        r"(?:explícame|explicame|explicá|explica|enseñame|enséñame)(?: cómo| qué| sobre)?",
        r"(?:modo|activa(?: el)?) aprendizaje",
        r"quiero (?:aprender|entender|saber)(?: sobre| cómo| qué)?",
        r"(?:aprende|aprendo) conmigo",
        r"no entiendo(?: cómo| qué| por qué)?",
        r"(?:qué es|cómo funciona|por qué)",
    ],
    "guardar_captura": [
        r"(?:guarda|captura|screenshot)(?: esto| la pantalla| esto que veo)?",
        r"guarda(?:me)? (?:una captura|esto|lo que veo|la pantalla)",
        r"(?:toma|sacá|saca) (?:una )? (?:captura|foto|screenshot)(?: de la pantalla)?",
        r"quiero guardar (?:esto|la pantalla|lo que veo)",
    ],
}

WAKE_WORDS = [r"\bvexa\b", r"\bvex[aá]\b"]


def detect_intent(text: str) -> Tuple[Optional[str], float]:
    """Detect intent from transcribed text. Returns (intent, confidence)."""
    t = text.lower().strip()
    for intent, patterns in COMMANDS.items():
        for pattern in patterns:
            if re.search(pattern, t):
                return intent, 1.0
    return None, 0.0


def is_wake_word(text: str) -> bool:
    """Check if text contains a VEXA wake word."""
    t = text.lower()
    return any(re.search(w, t) for w in WAKE_WORDS)


def get_help_text() -> str:
    return (
        "Puedo responder preguntas, controlar el PC, ejecutar agentes, "
        "poner recordatorios, leer la pantalla, y guardar notas en tu memoria. "
        "Di 'oye VEXA' seguido de tu comando. Ejemplos: "
        "'modo pc', 'describí la pantalla', 'guarda que tengo reunión mañana', "
        "'qué dice ese error', o simplemente hazme una pregunta."
    )
