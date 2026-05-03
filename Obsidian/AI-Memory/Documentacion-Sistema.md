# 📘 Documentación del Ecosistema de IA

> **Fecha:** 2026-04-26
> **Estado:** Sistema vivo, autónomo y optimizado.

Esta documentación resume el ecosistema de IA local que hemos construido en `/home/mash/Opencode/`.

---

## 1. Arquitectura del Sistema
El sistema está organizado para ser modular y fácil de mantener:

*   `/home/mash/Opencode/Base/`: Núcleo operativo.
    *   `scripts/`: Todos los comandos bash (`ia.sh`, agentes, tareas).
    *   `python/`: Lógica compleja (API, RAG, indexador).
    *   `logs/`: Registro de actividad de cada agente.
    *   `config/`: Configuración del sistema (ej: `mode.conf`).
*   `/home/mash/Opencode/Obsidian/AI-Memory/`: Tu "Segundo Cerebro" (Vault).
    *   `Notas/`: Tus notas generadas automáticamente.
    *   `Sistema/`, `Proyectos/`, `Conocimiento/`: Estructura jerárquica.

---

## 2. El Comando Central (`ia`)
Todo el sistema se gestiona a través del alias global `ia`.

| Comando | Función |
| :--- | :--- |
| `ia start/stop/status` | Gestiona los agentes de fondo (Monitor, Auto-restart, Auto-agente). |
| `ia chat` | Inicia una conversación por voz natural con la IA. |
| `ia analyze [nota]` | Analiza una nota buscando mejoras. |
| `ia memory "texto"` | Agente que clasifica y guarda ideas automáticamente. |
| `ia nota "título" "texto"`| Crea una nueva nota en `Notas/` enlazada al índice. |
| `ia task run` | Ejecuta las tareas pendientes programadas. |
| `ia rag buscar "q"` | Búsqueda semántica en tu base de conocimientos. |
| `ia master` | Orquestador: decide qué acción proactiva tomar ahora. |
| `ia meta` | Agente de metacognición: sugiere mejoras al sistema. |
| `ia maint` | Mantenimiento preventivo (limpieza, re-indexación). |
| `ia tui` | Dashboard visual en terminal. |

---

## 3. Servicios Autónomos (Funcionando 24/7)
Al iniciar tu PC, el comando `@reboot` en `crontab` ejecuta `ia start`.

*   **Auto-agente:** Corre cada 10 minutos. Ejecuta tareas, analiza el mantenimiento (`janitor`), procesa el `Inbox` y actualiza la memoria.
*   **Monitor:** Vigila RAM, Disco y servicios. Si algo falla, intenta reiniciarlo automáticamente (`Auto-restart`) y te envía una alerta crítica (`alerta-router`).
*   **Modo de escucha:** `ia always-listen` está listo para despertar cuando digas "sistema".

---

## 4. IA Viva: Autonomía y Proactividad
*   **Voz Natural:** Usamos `edge-tts` (voz neuronal de Microsoft) para interacciones naturales.
*   **Aprendizaje:** `ia feedback` te permite criticar a la IA para que ella misma reescriba sus instrucciones (`INSTRUCCIONES-IA.md`).
*   **Gestión de proyectos:** `ia dir` (Director) prioriza tus tareas automáticamente basándose en tu productividad real (`session-tracker.sh`).
*   **Documentación automática:** `ia gw` (Ghost Writer) documenta tus avances en GitHub automáticamente.

---

## 5. Mantenimiento y Logs
Si algo parece no funcionar, consulta los logs aquí:
*   `/home/mash/Opencode/Base/logs/`
    *   `auto-agente.log`: Qué hizo el agente autónomo.
    *   `ia-master.log`: Decisiones de la IA orquestadora.
    *   `analizar-notas.log`: Análisis de tus notas.
    *   `task-runner.log`: Tareas ejecutadas.

---
> **Nota:** Este sistema está diseñado para evolucionar contigo. Si sientes que algo es lento o no es útil, usa `ia feedback` para que la IA aprenda a mejorar su propio código.