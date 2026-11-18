# Aliento Andino

> Tutor virtual interactivo y red social de aprendizaje para **instrumentos de viento andinos** (Quena, Zampoña y Tarka).

Combina inferencia acústica y postural **100% On-Device (Edge AI)** con detección de frecuencia fundamental (YIN / SPICE), visión computacional (MediaPipe Pose + Hands), tutoría pedagógica mediante SLM local, aplicación móvil en Flutter, panel administrativo en Angular 21 y backend asíncrono en FastAPI (Python 3.12) con PostgreSQL 16.

---

## Documentación Técnica y Guías del Proyecto

Para mantener el principio de responsabilidad única y no duplicar contenido, los detalles técnicos se encuentran organizados en sus documentos específicos:

| Documento                                                                 | Qué contiene                                                                                                         |
| :------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------- |
| 📐 [**Arquitectura del Sistema**](docs/ARCHITECTURE.md)                   | Vistas 4+1 de Kruchten, Clean Architecture, flujo de datos y diagrama C4.                                            |
| 🚀 [**Guía de Despliegue e Infraestructura**](infra/DEPLOYMENT_GUIDE.md)  | Estrategia de despliegue dual: VPS monolítico vs Multi-Cloud Serverless/PaaS.                                        |
| 🏛️ [**Modelo C4 de Arquitectura**](docs/C4_MODEL.md)                      | Niveles 1 al 4: Contexto, Contenedores, Componentes y Código del sistema.                                            |
| 🎨 [**Sistema de Diseño Global**](DESIGN.md)                              | Tokens nucleares de color, tipografía base, accesibilidad y semántica andina.                                        |
| 💻 [**Diseño Web Admin (Angular)**](apps/web/DESIGN.md)                   | Grid responsivo de 12 columnas, sidebar, tablas de datos densas y métricas.                                          |
| 📱 [**Diseño Móvil (Flutter)**](apps/mobile/DESIGN.md)                    | Ley de Fitts, HUD de afinación en cents, digigramas andinos y ergonomía táctil.                                      |
| 💎 [**Estándares de Calidad**](docs/QUALITY_STANDARDS.md)                 | Estándar ISO/IEC 25010, ergonomía UI/UX y métricas de calidad de software.                                           |
| 💻 [**Estándares de Codificación**](docs/CODING_STANDARDS.md)             | Convenciones de estilo para Python, TypeScript/Angular, Dart/Flutter y SQL.                                          |
| 📋 [**Sprints e Historias de Usuario**](docs/SPRINTS_AND_USER_STORIES.md) | Backlog Scrum (Sprint 0 a 3), Historias de Usuario (HU-01 a 21) y trazabilidad con GitHub Issues.                    |
| 🛠️ [**Configuración y Setup**](docs/SETUP.md)                             | Instalación del entorno, dependencias globales y herramientas autónomas para agentes (Gentle AI, CodeGraph, Engram). |
| 🤝 [**Guía de Contribución**](CONTRIBUTING.md)                            | Flujo Git, ramas protegidas, Conventional Commits y Pull Requests.                                                   |
| 🤖 [**Reglas para Agentes de IA**](AGENTS.md)                             | Restricciones duras, mapa de servicios y directivas de desarrollo orgánico.                                          |
| 📖 [**Manual de Usuario Oficial**](apps/docs/)                            | Documentación interactiva en Docusaurus para estudiantes y docentes.                                                 |

---

## Mapa de Aplicaciones (`apps/`)

El repositorio está organizado bajo un monorepo administrado por **`pnpm`**:

```text
aliento-andino/
├── apps/
│   ├── backend/    # API REST central en FastAPI (Python 3.12) + SQLAlchemy 2 Async
│   ├── web/        # Panel web para docentes en Angular 21 (Signals + Standalone)
│   ├── mobile/     # App móvil para estudiantes en Flutter 3.x (Edge AI)
│   ├── ml/         # Microservicio de modelos acústicos y asistente semántico
│   └── docs/       # Manual de usuario interactivo en Docusaurus 3
├── infra/          # Configuración perimetral Nginx, scripts de backup y guías
└── docs/           # Arquitectura (ARCHITECTURE.md), estándares de calidad y código
```

---

## Inicio Rápido (Quickstart)

### 1. Instalación de Dependencias

Podés instalar las dependencias de todo el monorepo o de una aplicación en particular:

```bash
# Instalar dependencias de todo el ecosistema (Node, Python, Flutter)
pnpm install:all

# O por servicio individual:
pnpm install:web      # Panel Web Angular
pnpm install:docs     # Manual Docusaurus
pnpm install:backend  # Dependencias Python del Backend
pnpm install:ml       # Dependencias Python de ML
pnpm install:mobile   # Paquetes Flutter de la app móvil
```

### 2. Ejecución con Docker (Recomendado)

Todo el stack contenerizado (`db`, `backend`, `web`, `docs`, `ml`, `nginx`) se inicia con un único comando:

```bash
pnpm dev              # Iniciar todo el stack en segundo plano
pnpm dev:logs         # Ver logs en vivo
pnpm dev:down         # Detener contenedores

# O levantar servicios de forma independiente en Docker:
pnpm docker:backend   # Solo API Backend
pnpm docker:web       # Solo Panel Web
pnpm docker:docs      # Solo Manual de Usuario
pnpm docker:ml        # Solo Microservicio ML
pnpm docker:db        # Solo PostgreSQL
```

### 3. Ejecución en Host Local (Sin Docker)

```bash
pnpm dev:backend:host # Backend FastAPI en http://localhost:8050
pnpm dev:web:host     # Panel Web Angular en http://localhost:4250
pnpm dev:docs:host    # Manual Docusaurus en http://localhost:3050
pnpm dev:ml:host      # Microservicio ML en http://localhost:8051
pnpm dev:mobile:host  # App Flutter en emulador o dispositivo
```

> Para gestionar emuladores, dispositivos físicos por USB o depuración por Wi-Fi, consultar [`apps/mobile/README.md`](apps/mobile/README.md#ejecutar-en-desarrollo).

---

### 4. Datos de Prueba y Cuentas de Acceso (Seeders)

Para poblar la base de datos con lecciones andinas, logros, sesiones y comunidad de prueba:

```bash
docker compose exec backend python seed_lessons.py
docker compose exec backend python seed_achievements.py
docker compose exec backend python seed_all.py
```

Credenciales para ingresar tanto al panel Web (`:4250`) como a la app Móvil:

- **Administrador:** `admin@alientoandino.org` / `Admin1234!` (definido en `.env`)
- **Estudiantes (50 cuentas):** Contraseña universal `Andino123!` para todos los alumnos generados (ej: `alejandrogar@example.com`, `diegogom@example.com`, `monicasil@example.com`).

### 4. Datos de Prueba y Cuentas de Acceso (Seeders)

Para poblar la base de datos con lecciones andinas, logros, sesiones y comunidad de prueba:

```bash
docker compose exec backend python seed_lessons.py
docker compose exec backend python seed_achievements.py
docker compose exec backend python seed_all.py
```

Credenciales para ingresar tanto al panel Web (`:4250`) como a la app Móvil:

- **Administrador:** `admin@alientoandino.org` / `Admin1234!` (definido en `.env`)
- **Estudiantes (50 cuentas):** Contraseña universal `Andino123!` para todos los alumnos generados (ej: `alejandrogar@example.com`, `diegogom@example.com`, `monicasil@example.com`).

---

## Calidad y Verificación

Antes de enviar cualquier cambio, ejecutá las suites de verificación local:

```bash
pnpm format:check     # Verificar estilo Prettier en todo el monorepo
pnpm test:scripts     # Pruebas unitarias de scripts y validación de atribución AI
pnpm build:docs       # Validar compilación estática del manual Docusaurus
```

---

## Licencia

Este proyecto está bajo la Licencia MIT. Para más detalles, consultar [`LICENSE`](LICENSE).
