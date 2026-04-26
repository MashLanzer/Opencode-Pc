# Instrucciones para la IA — Sistema Autonomo

## Objetivo
Sistema de memoria persistente con agentes IA autónomos ejecutando en Linux Mint.

## Comandos principales

### Memoria
```bash
~/actualizar-memoria-ia.sh    # Actualizar fechas
~/backup-memoria-ia.sh       # Respaldar (mantiene 7 dias)
~/track-sesion-ia.sh [proyecto] [desc]  # Track de sesiones
```

### Agentes IA
```bash
~/analizar-notas.sh [nota]     # Analizar nota y sugerir acciones
~/resumen-sesion.sh            # Generar resumen automatico
~/memory-agent.sh "texto"     # Memory Agent decide donde guardar
```

### Sistema autonomo
```bash
~/auto-agente.sh start         # Iniciar agente autonomo
~/auto-agente.sh stop        # Detener agente
~/auto-agente.sh status     # Ver estado
~/auto-agente.sh run-once   # Ejecutar ciclo una vez
```

### Task Runner
```bash
~/task-runner.sh add "desc" "comando" [cron] [proyecto]
~/task-runner.sh list
~/task-runner.sh run
```

### CLI unificado
```bash
~/ia.sh analyze [nota]  # Analizar con IA
~/ia.sh summary        # Resumen automatico
~/ia.sh memory "txt"  # Memory Agent
~/ia.sh task add "desc" "cmd"
~/ia.sh run           # Ciclo unico
~/ia.sh start        # Iniciar agente
~/ia.sh stop        # Detener agente
~/ia.sh status      # Ver estado
```

## Ollama
```bash
~/.local/bin/ollama serve   # Iniciar servidor
~/.local/bin/ollama run llama3.2:1b  # Ejecutar modelo
~/ollama-manager.sh [modelo]      # Gestor Ollama
```

## Reglas

1. Al inicio: leer MEMORIA-PRINCIPAL.md
2. Al final: ejecutar ~/actualizar-memoria-ia.sh
3. Para analisis: usar ~/analizar-notas.sh
4. Para resumen automatico: usar ~/resumen-sesion.sh
5. Para guardar info: usar ~/memory-agent.sh
6. Agente autonomo: ~/auto-agente.sh start
7. Nunca sobrescribir historial, solo agregar

## Estructura AI-Memory

```
AI-Memory/
├── MEMORIA-PRINCIPAL.md
├── nota-rapida.md
├── tareas-pendientes.md
├── revision-diaria.md
├── indice-enlaces.md
├── indice-temas.md
├── Sistema/
│   ├── perfil-sistema.md
│   ├── software-instalado.md
│   ├── discos-y-particiones.md
│   ├── configuraciones-activas.md
│   ├── preferencias-usuario.md
│   ├── errores-y-soluciones.md
│   └── comandos-utiles.md
├── Proyectos/
│   ├── _indice-proyectos.md
│   ├── plantilla-proyecto.md
│   ├── plantilla-bug-report.md
│   └── plantilla-meeting.md
├── Conversaciones/
│   └── _resumen-general.md
└── Conocimiento/
    ├── plantilla-general.md
    ├── notas-generales.md
    └── snippets-codigo.md
```

## Quick reference

| Accion | Comando |
|--------|---------|
| Actualizar memoria | ~/actualizar-memoria-ia.sh |
| Analizar | ~/analizar-notas.sh |
| Resumen | ~/resumen-sesion.sh |
| Memory Agent | ~/memory-agent.sh |
| Agente auto | ~/auto-agente.sh start |
| Tareas | ~/task-runner.sh |
| CLI | ~/ia.sh |