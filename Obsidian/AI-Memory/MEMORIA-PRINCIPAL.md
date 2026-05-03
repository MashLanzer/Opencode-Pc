# 🧠 Memoria Principal — IA Assistant

> Fecha de creación: 2026-04-26
> Última sesión: 2026-04-27 19:58
> Estado del sistema: Activo — Autonomo

## ¿Qué es todo esto? (Guía para Mash)

Este es tu **segundo cerebro digital**. La IA guarda todo lo importante aquí: errores que solucionaste, comandos útiles, ideas para proyectos, resúmenes de conversaciones. Cuando necesites recordar algo, la IA busca en estas notas en lugar de inventar respuestas.

### ¿Cómo uso esto en mi día a día?

**No necesitas abrir Obsidian manualmente.** La IA gestiona todo por comandos en la terminal:

```bash
# Guardar una idea rápida

# Buscar algo que dijiste antes
ia rag buscar "configuración kitty"

# Ver qué tareas tienes pendientes
ia task list

# Iniciar sesión de trabajo (la IA mide el tiempo)
ia session start Godot

# Al terminar
ia session stop

# Ver estado de todo
ia status
```

---

## Estructura de carpetas

| Carpeta | Qué guarda aquí | Cuándo la uso |
|---------|----------------|---------------|
| **Sistema/** | Errores solucionados, comandos útiles, preferencias tuyas | Cuando algo falla o encuentro un comando bueno |
| **Conversaciones/** | Resúmenes de lo que hablamos | Para recordar contexto de sesiones pasadas |
| **Conocimiento/** | Snippets de código, notas generales | Código reutilizable o aprendizajes |
| **nota-rapida.md** | Ideas sueltas sin categorizar | Cualquier pensamiento rápido |
| **tareas-pendientes.md** | Checkboxes de cosas por hacer | Tareas actuales |

---

## Servicios que corren solos (Autónomos)

Cuando enciendes la PC, esto ya está funcionando:

| Servicio | Qué hace | ¿Por qué me importa? |
|----------|----------|---------------------|
| **Auto-agente** | Ejecuta tareas programadas cada 5 minutos | Limpia memoria, actualiza fechas, hace backups |
| **Monitor** | Revisa disco, RAM, procesos cada minuto | Te avisa si algo se llena o cae |
| **Auto-restart** | Vigila Ollama, Conky, Plank | Si se cierran, se reinician solos |
| **Ollama** | Motor de IA local (llama3.2:1b) | Permite que la IA piense sin internet |

**Comando único para controlarlos:**
```bash
ia start    # Iniciar todo
ia stop     # Detener todo
ia status   # Ver si corren
```

---

## Comandos principales (IA CLI)

### Guardar información
```bash
ia memory "texto"              # La IA decide dónde guardarlo
ia categorize "archivo.md"     # Mover a la carpeta correcta
ia task add "descripción"       # Agregar tarea pendiente
```

### Buscar información
```bash
ia rag buscar "kitty config"   # Búsqueda semántica (entiende significado)
ia rag buscar "error initramfs" # Encuentra errores pasados
```

### Analizar y resumir
```bash
ia analyze                     # Analizar MEMORIA-PRINCIPAL
ia summary                     # Resumen de la sesión actual
ia meta                        # Sugerencias para mejorar el sistema
```

### Productividad
```bash
ia session start ProyectoX   # Medir tiempo dedicado
ia session stop                # Parar y registrar
ia session report             # Ver horas por proyecto
ia maint                      # Mantenimiento manual (limpieza)
```

### Dashboard visual
```bash
ia tui                         # Interfaz visual en terminal
```

---

## ¿Dónde están los archivos del sistema?

Todo el código de la IA está organizado en:

```
/home/mash/Opencode/Base/
├── scripts/          # Comandos bash (ia.sh, auto-agente.sh, etc.)
├── python/           # APIs y buscadores (api-memoria.py, indexador.py)
└── docs/             # Instrucciones para la IA
```

**`ia` es un alias** que apunta a `/home/mash/Opencode/Base/scripts/ia.sh`. Puedes usarlo desde cualquier carpeta.

---

## Estado actual

- [x] Estructura organizada en /home/mash/Opencode/Base/
- [x] Servicios autónomos iniciados (Auto-agente, Monitor, Auto-restart)
- [x] Sistema RAG indexado y listo para consultas semánticas
- [x] Comando `ia` disponible globalmente
- [x] Inicio automático configurado (@reboot crontab)
- [x] Ollama funcionando con llama3.2:1b
- [x] **VEXA** — Sistema de voz animado operativo (`./VEXA/run.sh`)
  - Micrófono: hw:3,0 (USB MIC-E01) — detección automática USB corregida
  - UI: http://localhost:8765
  - Wake word: "oye VEXA" / "hey VEXA"
  - RAG integrado con memoria Obsidian

---

## Últimas conversaciones
→ Ver [[Conversaciones/_resumen-general]]

## Conocimiento acumulado
→ Ver [[Conocimiento/notas-generales]]
→ Ver [[Sistema/errores-y-soluciones]]