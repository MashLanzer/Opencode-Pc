# 📘 Guía Rápida — Comandos IA

> Para cuando olvides cómo usar el sistema

## Los 5 comandos que más usarás

| Quiero hacer... | Comando |
|----------------|---------|
| Guardar una idea | `ia memory "texto"` |
| Buscar algo que dije antes | `ia rag buscar "tema"` |
| Ver tareas pendientes | `ia task list` |
| Ver si todo funciona | `ia status` |
| Medir tiempo de trabajo | `ia session start Nombre` |

## Cuándo usar cada comando

**`ia memory "..."`**
- Cuando encuentras un error y lo solucionas
- Cuando aprendes un comando útil nuevo
- La IA decide dónde guardarlo automáticamente

**`ia rag buscar "..."`**
- Cuando no recuerdas cómo hiciste algo
- Cuando buscas configuraciones pasadas
- Busca por SIGNIFICADO, no solo palabras exactas

**`ia session start/stop`**
- Cuando empiezas a trabajar en un proyecto
- Para saber cuánto tiempo dedicas a cada cosa

**`ia task add "..." / ia task list`**
- Para no olvidar cosas pendientes
- La IA las ejecuta automáticamente si están programadas

## Si algo no funciona

```bash
ia stop    # Detener todo
ia start   # Reiniciar todo
ia status  # Ver qué está caído
```

## Estructura de archivos

La IA guarda todo en `/home/mash/Opencode/Obsidian/AI-Memory/`:
- **Sistema/** → Errores, comandos, preferencias
- **Conocimiento/** → Código, aprendizajes
- **Conversaciones/** → Resúmenes de sesiones