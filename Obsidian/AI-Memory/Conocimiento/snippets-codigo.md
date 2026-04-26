# 💻 Snippets de Código

> Actualizado: 2026-04-26

## Python

### Ler do arquivo
```python
def ler_arquivo(caminho):
    with open(caminho, 'r') as f:
        return f.read()
```

### Escribir do arquivo
```python
def escribir_arquivo(caminho, contenido):
    with open(caminho, 'w') as f:
        f.write(contenido)
```

### Ler do arquivo con encoding
```python
def ler_arquivo_encoding(caminho, encoding='utf-8'):
    with open(caminho, 'r', encoding=encoding) as f:
        return f.read()
```

---

## Bash

### Verificar si archivo existe
```bash
if [ -f "/ruta/archivo" ]; then
    echo "Archivo existe"
fi
```

### Obtener fecha
```bash
DATE_FMT=$(date '+%Y-%m-%d %H:%M')
```

### Loop por archivos
```bash
for archivo in /ruta/*.md; do
    echo "$archivo"
done
```

---

## JSON

### Parsear JSON en bash
```bash
cat archivo.json | jq '.campo'
```

---

## Git

### Crear commit con fecha
```bash
git add . && git commit -m "$(date '+%Y-%m-%d'): Actualización"
```

---

## Markdown

### Enlace a nota
```markdown
[[nombre-de-nota]]
```

### Tabla simple
```markdown
| Col1 | Col2 |
|------|------|
| dato | dato |
```