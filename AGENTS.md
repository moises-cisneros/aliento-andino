# AGENTS.md — Aliento Andino

Guía para agentes de IA que implementan código en este repositorio. Explica qué es el proyecto, dónde buscar, qué herramientas usar y qué reglas no se pueden romper. Los desarrolladores deben consultar [`CONTRIBUTING.md`](CONTRIBUTING.md). El detalle de cada área está en los documentos públicos enlazados: consultalos en vez de suponer.

---

## Qué es

Tutor virtual interactivo y red social de aprendizaje para **instrumentos de viento andinos** (Quena, Zampoña y Tarka). Combina inferencia acústica y postural **100% local (On-Device / Edge AI)** con detección de frecuencia fundamental (YIN / SPICE), visión por computadora (MediaPipe Pose + Hands), tutoría pedagógica mediante SLM local (Gemma 2 / Llama 3.2), aplicación móvil en Flutter 3.x, panel administrativo en Angular 21 y backend asíncrono en FastAPI (Python 3.12) con PostgreSQL 16.

---

## Mapa del repositorio

| Ruta            | Qué contiene                                                                                    |
| :-------------- | :---------------------------------------------------------------------------------------------- |
| `apps/backend/` | API REST central (FastAPI), servicios de negocio, modelos SQLAlchemy 2 async y Alembic          |
| `apps/web/`     | Panel administrativo web (Angular 21 standalone, Signals, Material, Lucide)                     |
| `apps/mobile/`  | Aplicación móvil para estudiantes (Flutter 3.x, BLoC, GoRouter, Dio, Drift SQLite)              |
| `apps/ml/`      | Microservicio ML de inferencia acústica, modelos de acordes y asistente semántico offline       |
| `apps/docs/`    | Manual de usuario oficial y guías interactivas (Docusaurus 3)                                   |
| `infra/`        | Configuraciones de infraestructura (VPS / Multi-Cloud), Nginx reverse proxy y scripts de backup |
| `docs/`         | Documentación técnica, modelo C4, estándares de calidad (`QUALITY_STANDARDS.md`) y codificación |
| `.github/`      | Workflows de CI/CD, templates de issues/PR, agentes especializados y comandos                   |
| `scripts/`      | Utilidades de verificación de repositorio y validación de atribución de IA                      |

---

## Dónde buscar

| Necesito…                                                                  | Documento                                                                                                               |
| :------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------- |
| Entender módulos, flujos entre servicios y arquitectura                    | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)                                                                          |
| Modelo C4 formal (Contexto, Contenedores, Componentes, Código)             | [`docs/C4_MODEL.md`](docs/C4_MODEL.md)                                                                                  |
| Tokens de diseño, paleta semántica y ergonomía táctil                      | [`DESIGN.md`](DESIGN.md), [`apps/web/DESIGN.md`](apps/web/DESIGN.md) y [`apps/mobile/DESIGN.md`](apps/mobile/DESIGN.md) |
| Estándares de calidad de software (ISO/IEC 25010) y ergonomía UI/UX        | [`docs/QUALITY_STANDARDS.md`](docs/QUALITY_STANDARDS.md)                                                                |
| Convenciones de código por tecnología, linters y comandos                  | [`docs/CODING_STANDARDS.md`](docs/CODING_STANDARDS.md)                                                                  |
| Consultar backlog, Sprints (0-3), HUs y trazabilidad de issues GitHub      | [`docs/SPRINTS_AND_USER_STORIES.md`](docs/SPRINTS_AND_USER_STORIES.md)                                                  |
| Estrategias de despliegue dual (VPS vs Multi-Cloud)                        | [`infra/DEPLOYMENT_GUIDE.md`](infra/DEPLOYMENT_GUIDE.md)                                                                |
| Flujo de trabajo con ramas, commits y PR                                   | [`CONTRIBUTING.md`](CONTRIBUTING.md)                                                                                    |
| Configurar e instalar herramientas del agente (Gentle AI, CodeGraph, etc.) | [`docs/SETUP.md`](docs/SETUP.md)                                                                                        |
| Licencia del software                                                      | [`LICENSE`](LICENSE)                                                                                                    |

Leé solo la sección que necesitás, no el archivo entero.

---

## Comandos

```bash
# --- Instalación de Dependencias ---
pnpm install:all          # Instala dependencias de todo el ecosistema (pnpm, pip, flutter)
pnpm install:web          # Solo dependencias del panel Web Angular (pnpm únicamente)
pnpm install:docs         # Solo dependencias del manual Docusaurus
pnpm install:backend      # Solo dependencias Python del Backend
pnpm install:ml           # Solo dependencias Python del microservicio ML
pnpm install:mobile       # Solo paquetes Flutter de la app móvil

# --- Orquestación Central Monorepo (Docker) ---
pnpm dev                  # Iniciar todos los servicios en segundo plano (docker compose up -d)
pnpm dev:build            # Reconstruir y levantar imágenes
pnpm dev:down             # Detener todos los contenedores
pnpm docker:backend       # Levantar solo backend
pnpm docker:web           # Levantar solo web admin
pnpm docker:docs          # Levantar solo manual de usuario

# --- Desarrollo en Host (Sin Docker) ---
pnpm dev:backend:host     # Backend FastAPI en http://localhost:8050
pnpm dev:web:host         # Panel Web Angular en http://localhost:4250
pnpm dev:docs:host        # Manual Docusaurus en http://localhost:3050
pnpm dev:ml:host          # Microservicio ML en http://localhost:8051
pnpm dev:mobile:host      # Flutter móvil en emulador o dispositivo

# --- Calidad y Verificación ---
pnpm format:check         # Prettier en todo el repositorio
pnpm build:docs           # Compilar estáticos de Docusaurus
cd apps/backend && ruff check . && ruff format --check . && pytest tests/ -v
cd apps/web && pnpm lint && pnpm test --run
cd apps/mobile && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test
node scripts/ai-attribution.mjs --range origin/main..HEAD # Verificar atribución AI
```

---

## Herramientas del Agente

Para trabajar con precisión quirúrgica y evitar suposiciones, usá estrictamente las herramientas indicadas según el tipo de tarea:

1. **CodeGraph (`codegraph_explore`)**:
   - Repositorio y docs: [github.com/colbymchenry/codegraph](https://github.com/colbymchenry/codegraph) | [npm: @colbymchenry/codegraph](https://www.npmjs.com/package/@colbymchenry/codegraph)
   - Usar **siempre** para explorar la estructura del código, árbol de llamadas, símbolos, tipos y dependencias antes de leer archivos completos.
2. **Ripgrep (`rg`)**:
   - Repositorio y docs: [github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
   - Usar para búsqueda de texto exacto, literales, JSON, fixtures, variables de entorno y documentación Markdown (`rg -n "patron"`, `rg -F "literal"`).
   - Preferir `rg` sobre `grep`/`find`/`cat`.
3. **Engram (`mem_context`, `mem_search`, `mem_save`)**:
   - Repositorio y docs: [github.com/Gentleman-Programming/engram](https://github.com/Gentleman-Programming/engram) | [Releases](https://github.com/Gentleman-Programming/engram/releases/latest)
   - Usar **siempre** al iniciar sesión o antes de decisiones arquitectónicas para consultar el historial del proyecto, PRs activas y convenciones (`mem_context`, `mem_search`).
   - Persistir descubrimientos no triviales, correcciones y convenciones con `mem_save`.
4. **Gentle AI y ODD (Organic Driven Development)**:
   - Repositorio y docs: [github.com/Gentleman-Programming/gentle-ai](https://github.com/Gentleman-Programming/gentle-ai)
   - Toda implementación de código debe seguir el protocolo **ODD**, nunca SDD:
     - **Autorizar**: Confirmar que el usuario autorizó mutar código (reviews/investigaciones son de solo lectura).
     - **Explorar**: Mapear antes de escribir usando CodeGraph y `rg`.
     - **Unidades Revisables**: Trabajar en rebanadas de ~400 líneas con tests y docs al lado.
     - **Verificar**: Probar inline o mediante verificación automatizada contra suites de tests.

---

> [!IMPORTANT]
> **Verificación e Instalación Obligatoria de Herramientas**:
> Al iniciar en este repositorio, el agente **DEBE verificar** la presencia de los ejecutables y herramientas MCP de **Gentle AI**, **CodeGraph**, **Engram** y **Ripgrep**.
> **Si alguna herramienta NO está instalada o configurada, el agente TIENE LA OBLIGACIÓN de instalarla y configurarla de forma autónoma antes de ejecutar cualquier tarea.**
> Consultar la guía completa de comandos, links y configuración en [`docs/SETUP.md`](docs/SETUP.md).

---

## Reglas duras (Inviolables)

1. **Dominio Andino Exclusivo**: Tutoría especializada únicamente en **Quena**, **Zampoña** y **Tarka**. Prohibido desviar a otros instrumentos.
2. **Inferencia de IA 100% Local (On-Device)**: El procesamiento acústico (pitch) y postural opera íntegramente en el cliente móvil. **PROHIBIDO** enviar streams de audio/video crudos a APIs externas o LLMs de nube en tiempo de ejecución.
3. **Consumo Estricto de Pautas de Diseño**: Toda implementación visual en Web o Móvil debe consumir exclusivamente los tokens de [`DESIGN.md`](DESIGN.md), [`apps/web/DESIGN.md`](apps/web/DESIGN.md) y [`apps/mobile/DESIGN.md`](apps/mobile/DESIGN.md). En móvil, respetar la **Ley de Fitts** (área táctil $\ge 48\text{px} \times 48\text{px}$, $52\text{px}$ en botones críticos).
4. **Continuidad de Nomenclatura y Contratos**: Tolerancia cero a discrepancias de nombres entre capas (ej. `get_lessons` vs `getLessons` alineados; schemas Pydantic, DTOs TypeScript y Models Dart idénticos).
5. **Calidad antes de terminar**: `ruff check`, `flutter analyze` y `pnpm lint` deben pasar con **0 errores y 0 warnings**. Cobertura mínima: $\ge 80\%$ backend, $\ge 75\%$ web y móvil. Suites al 100% en verde.
6. **Arquitectura por Capas Estricta**: En backend: `routers/` (HTTP/auth) $\rightarrow$ `services/` (lógica) $\rightarrow$ `models/` (ORM). Los routers nunca realizan consultas SQL directas ni contienen lógica de negocio.
7. **`pnpm` únicamente en Web**: Prohibido usar `npm` o `yarn` dentro de `apps/web/`.
8. **Manejo de Errores Honesto**: Prohibido simular datos falsos de afinación o éxito; mostrar siempre la causa real de cualquier error.
9. **Secretos**: Nunca commitear `.env*`, llaves privadas, tokens JWT ni credenciales en código o PRs.
10. **Prohibición Total de Atribución AI**: **NUNCA** incluir `Co-Authored-By`, `Assisted-by`, `Generated with...` ni firmas de asistentes de IA en commits, PRs o comentarios. El autor del commit siempre es el desarrollador.
11. **Identidad Git Estricta**: Todo commit debe firmarse bajo:
    - `user.name`: `moises-cisneros`
    - `user.email`: `moisescisnerosdl@gmail.com`
12. **Metodología ODD**: Implementar mediante Organic Driven Development con Gentle AI. Explorar antes de escribir y mantener un radio de impacto controlado.
13. **Prohibición Absoluta de Commits/Push Directos a `main`**: Está terminantemente prohibido commitear o pushear directamente a `main` (o `staging`). Todo cambio debe realizarse en una rama dedicada (`<tipo>/<numero-subissue>-<descripcion>`), y cada sub-issue debe cerrarse obligatoriamente mediante un Pull Request (`Closes #<subissue>`). Las issues madres (Historias de Usuario / HUs) se cierran cuando todas sus tareas/sub-issues estén resueltas (vía la última PR con `Closes #<hu>` o mediante la automatización `.github/workflows/close-parent-hu.yml`).
14. **Implementación Siempre en un Git Worktree**: Toda implementación (código, tests, docs) se hace en un `git worktree` propio, nunca en el checkout principal. Así `main` —o la rama que el desarrollador tenga abierta en su IDE— no se ensucia ni cambia de rama mientras el agente trabaja. Convención: `git worktree add -b <tipo>/<numero-subissue>-<descripcion> ../aliento-andino-worktrees/<nombre> origin/main`. Cada worktree usa su propio `.codegraph/` (nunca copiarlo ni enlazarlo desde otro checkout). Detalle en [`CONTRIBUTING.md`](CONTRIBUTING.md#22-ramas).

---

## Flujo de Ramas, Sub-issues y Pull Requests

```text
Sub-issue (GitHub) ──► Rama feat/<id>-<desc> ──► Commits atómicos ──► Pull Request ──► Squash & Merge ──► Cierre de Sub-issue y HU
```

1. **Una Rama y un PR por Sub-issue**:
   - Cada tarea técnica de una HU (`SUB-XX-X`) se trabaja en una rama propia creada desde `main` actualizado:
     `git worktree add -b feat/<subissue-id>-<descripcion-corta> ../aliento-andino-worktrees/<nombre> origin/main` (regla 14: nunca `git checkout -b` en el checkout principal)
   - Se implementan los cambios en unidades revisables (~400 líneas) con sus tests y documentación.
   - Se sube la rama y se abre el Pull Request hacia `main`.
2. **Cierre Automático de Sub-issues**:
   - La descripción del PR debe incluir obligatoriamente la directiva de cierre:
     `Closes #<subissue-id>` (ej. `Closes #9`).
   - Al fusionar el PR (Squash and Merge), GitHub cierra automáticamente la sub-issue correspondiente.
3. **Cierre de Historias de Usuario (Issues Madres / HU)**:
   - Una HU madre agrupa múltiples sub-issues técnicas (ej. `HU-01 #8` contiene `#9`, `#10` y `#11`).
   - Se cierra formalmente solo cuando **todas sus sub-issues están resueltas**:
     - **Vía la última PR de la HU**: El PR de la última subtarea pendiente añade `Closes #<id-hu>` junto con su sub-issue (ej. `Closes #11` y `Closes #8`).
     - **Vía Automatización GitHub Actions**: Si no se cerró en la última PR, el workflow [`.github/workflows/close-parent-hu.yml`](.github/workflows/close-parent-hu.yml) verifica que todas las casillas del checklist en la issue madre estén completadas (`- [x]`) y la cierra automáticamente con comentario explicativo.
4. **Protección Local de Git**:
   - El hook [`.husky/pre-push`](.husky/pre-push) bloquea automáticamente cualquier intento de `git push origin main`.
   - Si un agente o desarrollador intenta hacer push a `main`, el hook aborta la operación y exige crear una rama de feature y PR.

---

## Cosas que no son obvias

- **Inferencia de Pitch Híbrida**: En móvil se utiliza un algoritmo YIN optimizado en C++/Dart para retroalimentación instantánea ($<50\text{ms}$), y SPICE/CREPE para análisis detallado al finalizar la frase musical.
- **Telemetría Multimodal Compacta**: La postura (MediaPipe) y la afinación se compactan en un paquete JSON liviano ($<5\text{KB}$) entregado al SLM local (Gemma 2 / Llama 3.2) para redactar el feedback pedagógico en lenguaje natural offline.
- **Esquema de Notas Musicales**: Las notas de las lecciones se serializan en estructuras JSON estructuradas con frecuencia esperada, tolerancia en cents, digitación requerida y posición de orificios/tubos.
- **Idempotencia de Sesiones**: El cliente móvil envía un `client_id` (UUID) para evitar duplicación de XP o estadísticas en reintentos de red.
- **Semillas de Datos Idempotentes**: `python seed_all.py` limpia y regenera el estado consistente con categorías, lecciones, instrumentos andinos y usuarios de demostración.
- **CI Detecta Cambios**: El pipeline de CI corre únicamente las suites del área modificada (`backend`, `web`, `mobile`), acelerando los tiempos de verificación en Pull Requests.
