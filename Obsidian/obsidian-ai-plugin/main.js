import { Plugin, TFile } from 'obsidian';

export default class AIMemoryPlugin extends Plugin {
  async onload() {
    // Registrar comandos slash
    this.addCommand({
      id: 'ai-resumen',
      name: 'AI Resumen',
      editorCallback: (editor) => {
        this.ejecutarIA('resumen', editor);
      }
    });

    this.addCommand({
      id: 'ai-buscar',
      name: 'AI Buscar en memoria',
      editorCallback: (editor, ctx) => {
        this.ejecutarIA('buscar', editor);
      }
    });

    this.addCommand({
      id: 'ai-sugerir',
      name: 'AI Sugerir acciones',
      editorCallback: (editor) => {
        this.ejecutarIA('sugerir', editor);
      }
    });

    // Agregar botón en ribbon
    this.addRibbonIcon('brain', 'AI Memory', () => {
      this.mostrarPanel();
    });

    // Registrar proveedor para búsqueda
    this.registerView('ai-memory-panel', (leaf) => {
      return new AIMemoryPanel(leaf, this);
    });
  }

  async ejecutarIA(comando, editor) {
    const apiUrl = 'http://localhost:5000/api';
    
    try {
      let endpoint = '';
      let payload = {};
      
      switch(comando) {
        case 'resumen':
          endpoint = '/summary';
          break;
        case 'buscar':
          endpoint = '/buscar';
          const termino = editor.getSelection() || await this.prompt('Buscar:');
          payload = { query: termino };
          break;
        case 'sugerir':
          endpoint = '/sugerir';
          break;
      }
      
      const response = await fetch(apiUrl + endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      const data = await response.json();
      
      if (editor) {
        editor.replaceSelection(data.respuesta || data);
      } else {
        new Notice(data.respuesta || data);
      }
    } catch(e) {
      console.error(e);
      new Notice('Error: API no disponible');
    }
  }

  async mostrarPanel() {
    this.app.workspace.getLeaf('right').setViewState({
      type: 'ai-memory-panel'
    });
  }
}

class AIMemoryPanel extends ItemView {
  constructor(leaf, plugin) {
    super(leaf);
    this.plugin = plugin;
  }

  getViewType() { return 'ai-memory-panel'; }
  getDisplayText() { return 'AI Memory'; }

  async onOpen() {
    const container = this.containerEl;
    container.empty();
    
    container.createEl('h2', { text: 'AI Memory Assistant' });
    
    const botones = container.createEl('div', { cls: 'botones' });
    
    botones.createEl('button', { 
      text: 'Resumen', 
      cls: 'btn',
      onClick: () => this.plugin.ejecutarIA('resumen')
    });
    
    botones.createEl('button', { 
      text: 'Sugerir', 
      cls: 'btn',
      onClick: () => this.plugin.ejecutarIA('sugerir')
    });
  }
}