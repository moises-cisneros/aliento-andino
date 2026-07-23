# Estándar de Codificación — PianoVision AI

> **Anexo de codificación del proyecto.** Documenta las convenciones que sigue
> todo el código del sistema (backend, móvil y web) y las herramientas que las
> imponen automáticamente. Sirve como referencia para el equipo y como evidencia
> de cumplimiento del estándar exigido por la materia.

Última actualización: 2026-06-20

---

## 1. Principios generales

| Principio | Aplicación en PianoVision |
|-----------|---------------------------|
| **Un estándar por lenguaje** | Python → PEP 8 + ruff · Dart → Effective Dart + flutter_lints · TypeScript → Angular Style Guide + ESLint |
| **Formateo automático, no manual** | El formato lo decide la herramienta (`ruff format`, `dart format`, ESLint), no el criterio individual |
| **El linter es bloqueante en CI** | Ningún PR a `staging`/`main` se mergea si el linter o los tests fallan (ver `.github/workflows/deploy.yml`) |
| **Nombres descriptivos en el idioma del dominio** | Comentarios y textos de usuario en español; identificadores de código según la convención de cada lenguaje |
| **Tipado explícito** | Type hints obligatorios en Python; tipos en Dart/TS; sin `any`/`dynamic` salvo justificación |

---

## 2. Backend (Python / FastAPI)

**Herramienta:** [ruff](https://docs.astral.sh/ruff/) — linter + formateador.
**Configuración:** [`backend/pyproject.toml`](../backend/pyproject.toml)

```toml
[tool.ruff]
target-version = "py312"
line-length = 100

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP", "N", "SIM"]
```

| Regla | Significado | Convención resultante |
|-------|-------------|------------------------|
| `E`, `W` | pycodestyle (PEP 8) | Indentación 4 espacios, espaciado, longitud de línea ≤ 100 |
| `F` | pyflakes | Sin imports/variables sin usar |
| `I` | isort | Imports ordenados (stdlib → terceros → locales) |
| `N` | pep8-naming | `snake_case` funciones/variables, `PascalCase` clases, `UPPER_CASE` constantes |
| `B` | flake8-bugbear | Detecta patrones propensos a bugs |
| `UP` | pyupgrade | Sintaxis moderna de Python 3.12 |
| `SIM` | flake8-simplify | Simplificación de condicionales/bucles |

**Convenciones adicionales aplicadas en el código:**
- **Arquitectura por capas:** `routers/` (HTTP) → `services/` (lógica) → `models/` (ORM) → `schemas/` (Pydantic). Los routers no acceden directo al modelo sin pasar por un servicio.
- **Funciones privadas** con prefijo `_` (ej. `_build_post_response`, `_notify_mentions`).
- **Docstrings** de módulo y de función en español, con triple comilla.
- **Type hints** en todos los parámetros y retornos (`async def get_feed(db: AsyncSession, user_id: uuid.UUID) -> dict`).
- **Validación de entrada** siempre vía esquemas Pydantic (`schemas/`), nunca parseando `request` a mano.
- **SQL portable:** helpers en `app/utils/sql.py` (ej. `greatest`) en lugar de funciones específicas de un motor.

**Comando de verificación:**
```bash
cd backend && ruff check . && ruff format --check .
```

---

## 3. Móvil (Dart / Flutter)

**Herramienta:** [flutter_lints](https://pub.dev/packages/flutter_lints) + `dart format`.
**Configuración:** [`mobile/analysis_options.yaml`](../mobile/analysis_options.yaml)

```yaml
include: package:flutter_lints/flutter.yaml
```

| Convención | Regla |
|------------|-------|
| Clases / widgets | `PascalCase` (`PostCard`, `FeedBloc`) |
| Métodos / variables | `camelCase` (`_buildContent`, `isSavedByMe`) |
| Archivos | `snake_case` (`post_card.dart`, `feed_bloc.dart`) |
| Constructores `const` | Obligatorios donde sea posible (lint `prefer_const_constructors`) |
| Documentación | `///` para clases y métodos públicos |
| Liberar recursos | `dispose()` de controllers/streams/recognizers obligatorio |

**Arquitectura impuesta (Clean Architecture + BLoC):**
```
features/<feature>/
  data/        → models/ (DTOs), repositories/ (acceso a API/DB)
  presentation/
    bloc/      → eventos, estados y BLoC (lógica de UI)
    screens/   → pantallas
    widgets/   → componentes reutilizables
core/          → router, theme, network, notifications, database (transversal)
```

- **Patrón BLoC** para todo estado no trivial: eventos y estados separados, updates optimistas con revert en `catch`.
- **Repositorios inyectados** vía `RepositoryProvider.value` y consumidos con `context.read<XRepository>()`.
- **Cero colores hardcodeados:** siempre `Theme.of(context).colorScheme.*` / `AppTheme.*`.
- **Rutas centralizadas** en `core/router/app_router.dart` (go_router); navegación con `context.push('/...')`.

**Comando de verificación:**
```bash
cd mobile && flutter analyze && dart format --output=none --set-exit-if-changed .
```

---

## 4. Web (TypeScript / Angular)

**Herramienta:** [ESLint](https://eslint.org/) + `@angular-eslint`.
**Configuración:** [`web/eslint.config.js`](../web/eslint.config.js)

| Convención | Regla |
|------------|-------|
| Selector de componentes | prefijo `app` (`app-lessons-dashboard`) |
| Nombre de componentes (selector) | `kebab-case` |
| Clases / interfaces | `PascalCase` (`AuthService`, `UserModel`) |
| Propiedades / métodos | `camelCase` |
| Campos que mapean al API | `snake_case` permitido en interfaces de DTO (`full_name`, `auth_provider`) |
| Inyección de dependencias | `inject()` / `private readonly` |
| Estado reactivo | `signal()` / `computed()` (Angular signals) |
| Componentes | `standalone: true`, tipados estrictos, sin `any` |

**Comando de verificación:**
```bash
cd web && npm run lint
```

---

## 5. Control de versiones y commits

- **Modelo de ramas:** `dev` (por desarrollador: daniel, victor, julio, ivan, samuel) → `staging` (integración + pruebas) → `main` (producción).
- **Commits convencionales:** `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, con scope opcional — ej. `feat(social): engagement — guardar posts`.
- **Pull Requests obligatorios** hacia `staging` y `main`; el gate de CI (tests + lint) es **bloqueante**.
- **Secretos fuera del repositorio:** `.gitignore` excluye `.env`, `*.key`, `*.pem`, `*.jks`, credenciales JSON. Ningún secreto se versiona.

---

## 6. Resumen de comandos de verificación

| Capa | Lint | Formato | Tests |
|------|------|---------|-------|
| Backend | `ruff check .` | `ruff format --check .` | `pytest -q` |
| Móvil | `flutter analyze` | `dart format --set-exit-if-changed .` | `flutter test` |
| Web | `npm run lint` | (incluido en ESLint) | `npm test` |

Todos estos comandos se ejecutan automáticamente en el pipeline de CI
([`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)) en cada Pull
Request. Un fallo de lint o de tests **impide el merge**.
