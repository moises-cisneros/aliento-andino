# Guía de Configuración e Instalación del Entorno (Setup Guide)

Esta guía documenta la configuración completa del entorno para desarrolladores y agentes de IA en **Aliento Andino**. Contempla tanto el stack de herramientas obligatorias para agentes de IA (**Gentle AI**, **CodeGraph**, **Engram** y **Ripgrep**) como el entorno de desarrollo del monorepo (Node.js/pnpm, Python, Flutter, Docker y utilidades).

---

## 1. Herramientas del Agente de IA (Metodología ODD)

> [!IMPORTANT]
> **MANDATO OBLIGATORIO PARA CUALQUIER AGENTE**:
> Al iniciar sesión en este repositorio, el agente **DEBE verificar** la presencia de los ejecutables y herramientas MCP de **Gentle AI**, **CodeGraph**, **Engram** y **Ripgrep**.
> **Si alguna herramienta NO está instalada o configurada, el agente TIENE LA OBLIGACIÓN de instalarla y configurarla de forma autónoma antes de ejecutar cualquier tarea.**

### 1.1 Verificación Inicial de Estado

Ejecutar en la terminal:

```bash
gentle-ai --version
codegraph --version
engram --version
rg --version
```

Y comprobar que las herramientas MCP (`codegraph_explore`, `mem_context`, `mem_search`, `mem_save`, etc.) respondan en el entorno del agente.

### 1.2 Enlaces Oficiales y Documentación

| Herramienta        | Propósito                                                         | Repositorio / Documentación Oficial                                                                                                                                       |
| :----------------- | :---------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Gentle AI**      | Orquestación ODD, sincronización de skills, reglas y diagnósticos | [github.com/Gentleman-Programming/gentle-ai](https://github.com/Gentleman-Programming/gentle-ai)                                                                          |
| **CodeGraph**      | Grafo de conocimiento de código, llamadas y análisis de impacto   | [github.com/colbymchenry/codegraph](https://github.com/colbymchenry/codegraph) \| [npm: @colbymchenry/codegraph](https://www.npmjs.com/package/@colbymchenry/codegraph)   |
| **Engram**         | Memoria persistente cross-session y protocolo arquitectónico      | [github.com/Gentleman-Programming/engram](https://github.com/Gentleman-Programming/engram) \| [Releases](https://github.com/Gentleman-Programming/engram/releases/latest) |
| **Ripgrep (`rg`)** | Búsqueda ultrarrápida de texto exacto, literales y documentación  | [github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)                                                                                                    |

### 1.3 Instalación Autónoma

#### A. Gentle AI

- **Vía Go**:

  ```bash
  go install github.com/Gentleman-Programming/gentle-ai@latest
  ```

- **Alternativa sin Go**:
  Descargar el binario precompilado desde [Gentle AI Releases](https://github.com/Gentleman-Programming/gentle-ai/releases) y añadirlo al `PATH`.
- **Configuración y sincronización**:

  ```bash
  gentle-ai install    # Configura agentes en el host (Claude, Antigravity, Cursor, etc.)
  gentle-ai sync       # Sincroniza configuraciones, reglas y skills del stack
  gentle-ai doctor     # Diagnostica la integridad y salud del entorno
  ```

#### B. CodeGraph

- **Vía pnpm global** (recomendado):

  ```bash
  pnpm add -g @colbymchenry/codegraph
  ```

- **Vía npm global**:

  ```bash
  npm install -g @colbymchenry/codegraph
  ```

- **Configuración de MCP y generación de índice**:

  ```bash
  codegraph install --yes    # Registra automáticamente el servidor MCP en los agentes detectados
  # Si la carpeta .codegraph/ no existe en la raíz del proyecto:
  codegraph init             # Genera el índice local de símbolos, tipos y llamadas
  ```

#### C. Engram

- **Vía Go**:

  ```bash
  go install github.com/Gentleman-Programming/engram/v3/cmd/engram@latest
  ```

- **Alternativa sin Go**:
  Descargar el binario release correspondiente al sistema operativo desde [Engram Releases](https://github.com/Gentleman-Programming/engram/releases/latest) y colocarlo en el `PATH`.
- **Inicialización del proyecto**:

  ```bash
  # Si la carpeta .engram/ no existe en la raíz del proyecto:
  engram init
  ```

#### D. Ripgrep (`rg`)

- **Windows**: `winget install BurntSushi.ripgrep.MSVC` o `choco install ripgrep`
- **macOS**: `brew install ripgrep`
- **Linux**: `apt install ripgrep` o `dnf install ripgrep`
- **Vía Cargo**: `cargo install ripgrep`

### 1.4 Configuración MCP Estándar para Agentes e IDEs

Si el agente o IDE requiere configuración explícita de servidores MCP (ej. en `mcp_config.json`, `~/.claude.json` o configuración de plataforma), debe incorporar las siguientes entradas stdio:

```json
{
  "mcpServers": {
    "engram": {
      "command": "engram",
      "args": ["mcp", "--tools=agent"]
    },
    "codegraph": {
      "command": "codegraph",
      "args": ["serve", "--mcp"]
    }
  }
}
```

---

## 2. Entorno de Desarrollo del Monorepo

### 2.1 Requisitos del Sistema

- **Node.js**: `v20.x` o `v22.x` (LTS recomendado)
- **pnpm**: `v9.x` o superior (gestor exclusivo para Web y monorepo)
- **Python**: `3.12.x` (FastAPI y microservicio ML)
- **Flutter**: `3.x` / Dart `3.x` (para `apps/mobile/`)
- **Docker & Docker Compose**: v2.x (para orquestación de servicios en contenedores)
- **Git**: 2.40+ (identidad configurada obligatoria según [`CONTRIBUTING.md`](../CONTRIBUTING.md))

### 2.2 Instalación de Dependencias del Proyecto

El monorepo cuenta con scripts centralizados en la raíz (`package.json`):

```bash
# Instalación completa de todo el ecosistema (pnpm, pip backend, pip ml, flutter)
pnpm install:all

# O por aplicación específica:
pnpm install:web          # Solo dependencias de Angular web
pnpm install:backend      # Solo entorno virtual y dependencias FastAPI
pnpm install:ml           # Solo dependencias del microservicio ML
pnpm install:mobile       # Solo paquetes Flutter de apps/mobile/
pnpm install:docs         # Solo dependencias de Docusaurus 3
```

### 2.3 Puesta en Marcha

#### Vía Docker Compose (Recomendado para orquestación completa)

```bash
pnpm dev                  # Inicia PostgreSQL, Backend, ML, Web y Docs en segundo plano
pnpm dev:down             # Detiene todos los contenedores
pnpm docker:backend       # Levanta únicamente el backend
pnpm docker:web           # Levanta únicamente el panel web
```

#### En Host Local (Sin Docker)

```bash
pnpm dev:backend:host     # Backend FastAPI en http://localhost:8050
pnpm dev:web:host         # Panel Web Angular en http://localhost:4250
pnpm dev:docs:host        # Manual Docusaurus en http://localhost:3050
pnpm dev:ml:host          # Microservicio ML en http://localhost:8051
pnpm dev:mobile:host      # App móvil Flutter en emulador o dispositivo físico
```

> **Dispositivos móviles (Emulador, USB o Wi-Fi):**
> Para listar y seleccionar emuladores (`flutter emulators`), dispositivos conectados por USB (`flutter devices`) o configurar depuración inalámbrica por Wi-Fi (`adb tcpip` / `adb pair`), consultar la guía detallada en [`apps/mobile/README.md`](../apps/mobile/README.md#ejecutar-en-desarrollo).

### 2.4 Verificación de Calidad

```bash
pnpm format:check         # Verifica estilo con Prettier en todo el repositorio
cd apps/backend && ruff check . && pytest tests/ -v
cd apps/web && pnpm lint && pnpm test --run
cd apps/mobile && flutter analyze && flutter test
```
