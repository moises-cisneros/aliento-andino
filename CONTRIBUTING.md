# Guía de Contribución — Aliento Andino

Cómo colaboramos en el equipo: desde la creación de un issue hasta el código en producción. El objetivo es que cualquier cambio sea **trazable** (a una Historia de Usuario y un Requisito), **revisado** por el compañero y **verificado** de forma automatizada antes de entrar a `staging` o `main`.

---

## 1. Preparar el Entorno

| Requisito            | Versión Recomendada          | Propósito                                        |
| :------------------- | :--------------------------- | :----------------------------------------------- |
| **Docker & Compose** | Docker 24+ / Compose v2      | Entorno canónico de Backend y PostgreSQL         |
| **Python**           | 3.12+                        | Desarrollo de API FastAPI y procesamiento ML     |
| **Node.js**          | $\ge 22$                     | Herramientas de repositorio, linters y Web Admin |
| **pnpm**             | $\ge 10$ (`corepack enable`) | Gestor de paquetes exclusivo de Web y raíz       |
| **Flutter SDK**      | 3.x (canal stable)           | Desarrollo y compilación de la app móvil         |

### Inicio Rápido con Docker Compose

```bash
# 1. Clonar el repositorio
git clone https://github.com/moises-cisneros/aliento-andino.git
cd aliento-andino

# 2. Instalar dependencias de herramientas en la raíz
pnpm install

# 3. Iniciar Backend y PostgreSQL
docker compose -f docker-compose.local.yml up -d --build

# 4. Poblar la base de datos con lecciones y usuarios de prueba
docker compose -f docker-compose.local.yml exec backend python seed_all.py

# 5. Iniciar la aplicación Web Admin
cd web && pnpm start

# 6. Iniciar la aplicación Móvil
cd mobile && flutter run
```

---

## 2. Flujo de Trabajo

```text
Sub-issue (GitHub) ──► Rama feat/<id>-<desc> ──► Commits atómicos ──► Pull Request ──► Squash & Merge ──► Cierre de Sub-issue y HU
```

1. **Todo cambio nace de un Issue**: No se aceptan ramas ni PRs huérfanos.
2. **Una sub-issue = Una rama = Un PR**: Cada subtarea técnica de una HU se desarrolla en su propia rama y se cierra mediante su propio PR hacia `main`.
3. **Prohibición de push directo a `main`**: `main` y `staging` son ramas protegidas. Ningún commit ingresa directamente; el hook local `.husky/pre-push` y las reglas del repositorio bloquean cualquier push directo.
4. Creas la rama desde `main` actualizado (`git checkout -b <tipo>/<id-subissue>-<desc>`).
5. Trabajas con commits atómicos de tamaño moderado (~400 líneas).
6. Abres un Pull Request que referencia la sub-issue (`Closes #<id-subissue> · Refs #<id-hu>`).
7. Se verifica que todos los checks automáticos de CI estén en verde.
8. Se integra mediante **Squash and Merge** y se elimina la rama de trabajo.
9. La Historia de Usuario madre se cierra cuando todas sus sub-issues están resueltas (en la última PR o vía `.github/workflows/close-parent-hu.yml`).

---

### 2.1 Issues

Cada issue debe poder trabajarse de forma independiente y medible.

> 📋 **Catálogo de Sprints e Issues**: El desglose completo de Sprints (Sprint 0 a 3), Historias de Usuario (HU-01 a HU-16) y Sub-issues técnicos vinculados a sus respectivos números de issue en GitHub se encuentra documentado en [`docs/SPRINTS_AND_USER_STORIES.md`](docs/SPRINTS_AND_USER_STORIES.md).

**Estructura de Issue:**

```markdown
## Contexto

Por qué hace falta este cambio (1-3 líneas).

## Trazabilidad

- Historia de Usuario / Requisito: HU-XX / RF-XX
- Instrumentos afectados: Quena / Zampoña / Tarka / General

## Qué hay que hacer

- [ ] Tarea específica 1
- [ ] Tarea específica 2

## Criterios de Aceptación

- [ ] Comportamiento observable y verificable
- [ ] Prueba automatizada que lo cubre (Pytest, Flutter Test o Vitest)

## Fuera de Alcance

Lo que este issue NO cubre explícitamente.
```

**Labels del Repositorio:**

- **Tipo**: `type:feature`, `type:bug`, `type:refactor`, `type:docs`, `type:test`, `type:chore`.
- **Área**: `area:backend`, `area:mobile`, `area:web`, `area:ml`, `area:infra`, `area:docs`.
- **Prioridad**: `priority:high`, `priority:medium`, `priority:low`.

---

### 2.2 Ramas

Nomenclatura obligatoria: `<tipo>/<numero-issue>-<descripcion-corta>` en minúsculas y con guiones:

```text
feat/12-detector-pitch-quena
fix/18-recuperacion-audio-player
refactor/25-aislar-servicios-lecciones
docs/30-actualizar-estandares-calidad
```

Tipos permitidos: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`. **Prohibido realizar commits directos sobre `main` o `staging`.**

#### Trabajar en un `git worktree`

Implementá cada rama en un worktree propio, **no** con `git checkout -b` en el checkout principal. El checkout principal queda intacto (en `main` o en la rama que tengas abierta en el IDE) y podés tener varias ramas en paralelo sin `stash` ni cambios de rama.

```bash
# Desde el checkout principal: un worktree hermano por rama, basado en main actualizado
git fetch origin
git worktree add -b feat/59-descarga-offline ../aliento-andino-worktrees/hu-18-offline origin/main

cd ../aliento-andino-worktrees/hu-18-offline
pnpm install:all          # o solo el área que toques (cada worktree tiene sus propias dependencias)
# ... implementar, commitear, abrir el PR desde esta carpeta ...

# Al mergear el PR: limpiar
cd -
git worktree remove ../aliento-andino-worktrees/hu-18-offline
git branch -d feat/59-descarga-offline
```

- Ubicación: `<padre-del-repo>/aliento-andino-worktrees/<nombre>`, siempre fuera del repo.
- La identidad Git (`user.name` / `user.email`) se verifica en cada worktree antes del primer commit.
- Cada worktree necesita su propio índice `.codegraph/` (`gentle-ai codegraph init --cwd <worktree>`); no lo copies ni lo enlaces desde otro checkout.
- Un mismo branch no puede estar abierto en dos worktrees a la vez: git lo impide.

---

### 2.3 Commits

Seguimos la convención de [Conventional Commits](https://www.conventionalcommits.org/):

```text
<tipo>(<alcance>): <descripcion en minuscula, sin punto final>
```

- **Tipos válidos**: `feat`, `fix`, `refactor`, `perf`, `style`, `docs`, `test`, `build`, `ci`, `chore`, `revert`.
- **Alcances sugeridos**: `backend`, `mobile`, `web`, `ml`, `audio`, `infra`, `auth`, `lessons`, `social`, `docs`.
- **Ejemplos**:
  - `feat(audio): add yin pitch detection for quena`
  - `fix(mobile): prevent fitts touch target clipping on small screens`
  - `docs(quality): update iso 25010 mapping`

#### Identidad Git y Prohibición de Atribución AI

1. **Identidad Obligatoria**:
   - `git config user.name "moises-cisneros"`
   - `git config user.email "moisescisnerosdl@gmail.com"`
2. **Cero Atribución AI**:
   - Está terminantemente prohibido incluir firmas como `Co-authored-by: <ai>`, `Assisted-by:`, `Generated by AI` o menciones similares en commits o PRs.
   - Lo audita el hook local `commit-msg`, el script `scripts/ai-attribution.mjs` y el workflow de CI `pr-conventions.yml`.

---

### 2.4 Verificaciones Automáticas: Hooks Locales y CI

| Capa                   | Cuándo se Ejecuta                    | Qué Verifica                                                   |       ¿Se Puede Omitir?        |
| :--------------------- | :----------------------------------- | :------------------------------------------------------------- | :----------------------------: |
| **Husky `pre-commit`** | Al ejecutar `git commit`             | Prettier sobre archivos en stage (`lint-staged`)               | No recomendado (`--no-verify`) |
| **Husky `commit-msg`** | Al ejecutar `git commit`             | Formato Conventional Commits y Cero Atribución AI              |         No recomendado         |
| **CI (`ci.yml`)**      | En cada PR y push a `main`/`staging` | Formato, linters (`ruff`, `flutter analyze`, `eslint`) y tests |      **No (Bloqueante)**       |
| **PR Conventions**     | En cada Pull Request                 | Título, commits y descripción sin atribución de IA             |      **No (Bloqueante)**       |
| **Repo Guard**         | Issues, comentarios y PRs            | Colaboradores autorizados y remoción de atribución AI          |           Automático           |

---

### 2.5 Pull Requests

- **Tamaño Óptimo**: Menos de 400 líneas modificadas por unidad revisable.
- **Título**: Mismo formato de un Conventional Commit (será el mensaje del squash commit).
- **Descripción**: Utiliza automáticamente la plantilla [`.github/pull_request_template.md`](.github/pull_request_template.md).
- **Cierre de Sub-issues**:
  - Cada PR **debe** incluir obligatoriamente `Closes #<id-subissue>` en la descripción para que GitHub la cierre al fusionar.
  - Ejemplo: `Closes #9 · Refs #8`
- **Cierre de Historias de Usuario (Issues Madres / HU)**:
  - Una HU madre agrupa sus sub-issues técnicas (ver [`docs/SPRINTS_AND_USER_STORIES.md`](docs/SPRINTS_AND_USER_STORIES.md)).
  - La HU se cierra cuando **todas sus subtareas están completadas**:
    1. **Vía la última PR**: La PR de la última sub-issue pendiente añade `Closes #<id-hu>` junto a su propia sub-issue (ej. `Closes #11` y `Closes #8`).
    2. **Automático vía GitHub Actions**: Si no se cerró en la PR, el workflow [`.github/workflows/close-parent-hu.yml`](.github/workflows/close-parent-hu.yml) audita las casillas completadas de la HU y la cierra automáticamente.
- **Condiciones de Fusión (Merge)**:
  - 100% de los checks de CI en verde (`CI passed`, `Commits & attribution`).
  - Conversaciones resueltas.
  - Rama al día con la rama base.
  - Exclusivamente **Squash and Merge**.

---

## 3. Definición de "Terminado" (Definition of Done)

Una tarea o issue se considera formalmente **Terminado** cuando:

- [ ] Cumple todos los criterios de aceptación especificados en el issue.
- [ ] Cuenta con pruebas automatizadas (unitarias o de integración) que validan el comportamiento.
- [ ] Los linters de la plataforma afectada pasan sin observaciones (`ruff`, `flutter analyze` o `eslint`).
- [ ] No existen diferencias de formateo (`pnpm format:check`).
- [ ] La documentación afectada ha sido actualizada (ver tabla de la Sección 4).
- [ ] El PR fue aprobado y fusionado en la rama principal.

---

## 4. Qué Documento Actualizar

| Si el cambio…                                                   | Actualizar                                                                                                                       |
| :-------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- |
| Modifica módulos, flujos entre servicios o esquema global       | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)                                                                                   |
| Agrega o modifica tokens visuales, colores o pautas de interfaz | [`DESIGN.md`](DESIGN.md) (global), [`apps/web/DESIGN.md`](apps/web/DESIGN.md) o [`apps/mobile/DESIGN.md`](apps/mobile/DESIGN.md) |
| Cambia reglas de calidad, cobertura mínima o criterios UI/UX    | [`docs/QUALITY_STANDARDS.md`](docs/QUALITY_STANDARDS.md)                                                                         |
| Cambia convenciones de código, linters o comandos               | [`docs/CODING_STANDARDS.md`](docs/CODING_STANDARDS.md)                                                                           |
| Cambia herramientas de desarrollo, entorno o setup del agente   | [`docs/SETUP.md`](docs/SETUP.md)                                                                                                 |
| Cambia reglas duras operativas o guías para asistentes de IA    | [`AGENTS.md`](AGENTS.md)                                                                                                         |
| Modifica requerimientos funcionales, arquitectura o modelo C4   | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) y [`docs/C4_MODEL.md`](docs/C4_MODEL.md)                                          |

> **Regla de Oro**: Un dato vive en un solo documento; los demás lo enlazan para evitar duplicaciones.

---

## 5. Despliegue

- El despliegue de producción se gestiona mediante [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) únicamente tras la aprobación exitosa del pipeline de CI sobre la rama `main`.
- Los secretos de infraestructura (tokens, credenciales SSH, llaves de servicio) se configuran en los Secrets del repositorio en GitHub, **nunca en código fuente**.

---

## 6. Seguridad y Secretos

1. **Prohibición de Archivos `.env`**: `.gitignore` excluye `.env`, certificados SSL, llaves privadas y archivos de cuentas de servicio. Si un secreto se commitea por error, debe revocarse y rotarse inmediatamente.
2. **Repositorio Protegido**: El workflow `repo-guard.yml` cierra automáticamente PRs o issues provenientes de usuarios no colaboradores del equipo.
3. **Auditoría de Dependencias**: Nuevas dependencias deben revisarse con `pnpm audit` (en web/raíz) y `pip audit` (en backend).
