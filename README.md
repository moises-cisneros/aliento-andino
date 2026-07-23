# PianoVision AI

Plataforma de aprendizaje de piano con tres componentes:

- **Backend** — API FastAPI (Python) con PostgreSQL, autenticación JWT + Google OAuth, sistema de logros y ranking.
- **Web** — Panel de administración Angular (gestión de lecciones, usuarios, reportes, moderación, rankings).
- **Mobile** — App Flutter para alumnos (Android / iOS / Web).

Desplegado en **Google Cloud (VM + Artifact Registry)** vía GitHub Actions.

📐 Para detalles arquitectónicos profundos (componentes, flujos, decisiones de diseño) ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Tabla de contenidos

1. [Arquitectura](#arquitectura)
2. [Requisitos previos](#requisitos-previos)
3. [Setup local](#setup-local)
4. [Cómo correr los servicios](#cómo-correr-los-servicios)
5. [Variables de entorno](#variables-de-entorno)
6. [Despliegue a Google Cloud](#despliegue-a-google-cloud)
7. [Tareas frecuentes](#tareas-frecuentes)
8. [Troubleshooting](#troubleshooting)

---

## Arquitectura

```
┌─────────────────┐      ┌─────────────────┐      ┌──────────────┐
│  Mobile (Flutter)│      │  Web Admin      │      │   GitHub     │
│  Android / iOS  │──┐   │  (Angular 21)   │      │   Actions    │
└─────────────────┘  │   └────────┬────────┘      └──────┬───────┘
                     │            │                       │ build & push
                     │            │ HTTPS                 ▼
                     │            │              ┌─────────────────┐
                     │            │              │ Artifact Registry│
                     │            ▼              │  (GCP)          │
                     │   ┌────────────────┐      └────────┬────────┘
                     └──▶│  Nginx + SSL   │               │ pull
                         │   (Certbot)    │               ▼
                         └────────┬───────┘      ┌─────────────────┐
                                  │              │  GCP VM         │
                                  ▼              │  Docker Compose │
                         ┌────────────────┐      │  ┌───────────┐  │
                         │  FastAPI       │◀─────│  │ Postgres  │  │
                         │  (uvicorn)     │      │  └───────────┘  │
                         └────────────────┘      └─────────────────┘
```

| Componente | Stack | Puerto local | Despliegue |
|---|---|---|---|
| Backend  | FastAPI + SQLAlchemy + Alembic + asyncpg | 8000 | Docker image en GCP Artifact Registry |
| Web      | Angular 21 + Angular Material + Lucide  | 4200 | Docker image (nginx) en GCP |
| Mobile   | Flutter + Dio                            | — / 5000 (web) | APK / build manual |
| DB       | PostgreSQL 16                            | 5432 | Docker en la misma VM |
| Proxy    | Nginx + Certbot                          | 80/443 | Docker en la misma VM |

---

## Requisitos previos

| Herramienta | Versión mínima | Notas |
|---|---|---|
| **Python** | 3.10+ | con `pip` y `venv` |
| **Node.js** | 18+ | con `npm` |
| **Flutter** | 3+ | con Dart SDK incluido |
| **PostgreSQL** | 14+ | instalación nativa (no Docker en local) |
| **Git Bash** | — | terminal recomendada en Windows |

---

## Setup local

> Asumimos Windows + Git Bash. En Mac/Linux las rutas y comandos de activación cambian.

### 1. Clonar y configurar variables de entorno

```bash
git clone <repo-url> PianoVision
cd PianoVision
```

Crear `backend/.env` con la configuración del backend (ver [Variables de entorno](#variables-de-entorno)).

### 2. Backend (FastAPI)

```bash
cd backend
python -m venv venv
source venv/Scripts/activate          # Windows / Git Bash
# source venv/bin/activate            # Mac / Linux
pip install -r requirements.txt
pip install -r requirements-test.txt  # solo si vas a correr tests
alembic upgrade head                  # aplicar migraciones
```

### 3. Web (Angular)

```bash
cd web && npm install
```

### 4. Mobile (Flutter)

```bash
cd mobile && flutter pub get
flutter devices                       # verificar dispositivos disponibles
```

---

## Cómo correr los servicios

Abrí **3 terminales** en VS Code (`Ctrl+Shift+5` para split).

### Terminal 1 — Backend

```bash
cd backend
source venv/Scripts/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

→ http://localhost:8000 · docs: http://localhost:8000/docs

### Terminal 2 — Web

```bash
cd web
npm start
```

→ http://localhost:4200

### Terminal 3 — Mobile

**En emulador Android:**

```bash
cd mobile
flutter emulators --launch <emulator-id>   # ver IDs con: flutter emulators
flutter run -d emulator-5554
```

**En Chrome (rápido para testing UI):**

```bash
flutter run -d chrome --web-port 5000
```

**En Windows desktop:**

```bash
flutter run -d windows
```

Comandos útiles del terminal Flutter:
- `r` → hot reload
- `R` → hot restart
- `q` → salir

> **Nota Android:** desde el emulador, el backend en tu host se accede vía `http://10.0.2.2:8000` — esto ya está manejado automáticamente en [mobile/lib/core/config/app_config.dart](mobile/lib/core/config/app_config.dart).

---

## Variables de entorno

### `backend/.env`

```ini
DATABASE_URL=postgresql+asyncpg://pianovision:localdev123@localhost:5432/pianovision
SECRET_KEY=dev-secret-key-cambiar-en-produccion
GOOGLE_CLIENT_ID=tu-client-id.apps.googleusercontent.com
CORS_ORIGINS=["http://localhost:4200","http://localhost:4000","http://localhost:8000"]
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu-email@gmail.com
SMTP_PASSWORD=tu-app-password-de-google
SMTP_FROM_NAME=PianoVision AI
SMTP_FROM_EMAIL=tu-email@gmail.com
FRONTEND_URL=http://localhost:4200
DEBUG=true
```

### `.env.production` (en la VM de GCP, **NO commitear**)

Variables usadas por `infra/docker-compose.yml` en producción. Mismas que `backend/.env` más las de Postgres y Docker:

```ini
# Postgres
POSTGRES_USER=pianovision
POSTGRES_PASSWORD=<password-fuerte>
POSTGRES_DB=pianovision

# Backend
DATABASE_URL=postgresql+asyncpg://pianovision:<password>@db:5432/pianovision
SECRET_KEY=<secret-fuerte>
GOOGLE_CLIENT_ID=<id>.apps.googleusercontent.com
CORS_ORIGINS=https://tu-dominio.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<email>
SMTP_PASSWORD=<app-password>
SMTP_FROM_EMAIL=<email>
FRONTEND_URL=https://tu-dominio.com
DEBUG=false

# Docker
DOCKER_REGISTRY=us-central1-docker.pkg.dev/pianovision-prod-12345/pianovision
IMAGE_TAG=latest
```

---

## Despliegue a Google Cloud

### Infraestructura

| Recurso | Uso |
|---|---|
| **GCP VM** (Compute Engine) | Host de Docker Compose con backend, web, DB, nginx, certbot |
| **Artifact Registry** | Almacena imágenes Docker `pianovision-backend` y `pianovision-web` |
| **GitHub Actions** | Build + push de imágenes en cada `push` a `main`, deploy vía SSH |

### Pipeline automático

Cada push a `main` dispara [.github/workflows/deploy.yml](.github/workflows/deploy.yml):

1. **Build & push** — construye las imágenes de `backend/` y `web/`, las sube a Artifact Registry con tag `:${GITHUB_SHA}` y `:latest`.
2. **Deploy** — se conecta vía SSH a la VM, copia `infra/docker-compose.yml` + `infra/nginx/`, hace `pull` de las nuevas imágenes, recrea los contenedores, corre migraciones de Alembic y los seeds.
3. **Verify** — confirma que el backend responde en `/docs`.

### Secrets requeridos en GitHub

Configurar en `Settings → Secrets and variables → Actions`:

| Secret | Valor |
|---|---|
| `GCP_SA_KEY` | JSON de service account con permisos sobre Artifact Registry |
| `DOCKER_REGISTRY` | `us-central1-docker.pkg.dev/PROJECT_ID/pianovision` |
| `VM_HOST` | IP pública o dominio de la VM |
| `VM_USER` | Usuario SSH de la VM |
| `VM_SSH_KEY` | Clave privada SSH (formato OpenSSH) |

### Seeds que corre el deploy

El pipeline ejecuta estos scripts **idempotentes** en cada deploy:

| Script | Qué carga |
|---|---|
| [backend/seed_achievements.py](backend/seed_achievements.py) | 23 logros predefinidos (práctica, social, racha, etc.) |
| [backend/seed_lessons.py](backend/seed_lessons.py) | Categorías y lecciones base (Escalas, Acordes, Melodías, Ritmo) |
| [backend/seed_all.py](backend/seed_all.py) | Datos de demo: 50 usuarios, XP, posts, likes, follows, logros desbloqueados |

> Son **complementarios**, no duplicados. Los tres siempre detectan si ya hay datos y no duplican.

### Deploy manual (si necesitás saltarte CI)

Desde tu máquina, con las imágenes ya pusheadas:

```bash
ssh user@vm-ip
cd ~/pianovision
docker compose --env-file .env.production pull
docker compose --env-file .env.production up -d
docker compose --env-file .env.production exec backend alembic upgrade head
```

### SSL con Let's Encrypt

Primera vez (la VM necesita el dominio apuntando a su IP):

```bash
docker compose --env-file .env.production run --rm certbot certonly \
  --webroot -w /var/www/certbot -d tu-dominio.com
```

Renovación automática (cron en la VM):

```cron
0 3 * * * cd ~/pianovision && docker compose run --rm certbot renew && docker compose exec nginx nginx -s reload
```

---

## Tareas frecuentes

### Crear una nueva migración de DB

```bash
cd backend
source venv/Scripts/activate
alembic revision --autogenerate -m "descripcion del cambio"
alembic upgrade head
```

### Correr tests del backend

```bash
cd backend
source venv/Scripts/activate
pytest
```

### Correr tests del mobile

```bash
cd mobile
flutter test
```

### Construir APK de release

```bash
cd mobile
flutter build apk --release
# salida: build/app/outputs/flutter-apk/app-release.apk
```

### Linting / formato

```bash
# Web
cd web && npm run lint

# Mobile
cd mobile && flutter analyze && dart format lib/

# Backend
cd backend && source venv/Scripts/activate && ruff check . && ruff format .
```

### Limpiar caches locales

```bash
# Mobile
cd mobile && flutter clean

# Web
cd web && rm -rf .angular dist node_modules && npm install

# Backend
cd backend && find . -type d -name __pycache__ -exec rm -rf {} +
```

### Backup manual de Postgres en producción

```bash
ssh user@vm-ip
cd ~/pianovision
docker compose --env-file .env.production exec -T db \
  pg_dump -U $POSTGRES_USER -d $POSTGRES_DB --no-owner --no-acl \
  | gzip > backup_$(date +%Y%m%d).sql.gz
```

Para restaurar:

```bash
gunzip -c backup_20260516.sql.gz | docker compose --env-file .env.production exec -T db \
  psql -U $POSTGRES_USER -d $POSTGRES_DB
```

---

## Troubleshooting

### Backend: `ModuleNotFoundError`

El venv no está activado. Ejecutá `source venv/Scripts/activate` antes de `uvicorn`.

### Backend: `connection refused` a PostgreSQL

PostgreSQL no está corriendo o las credenciales en `.env` no coinciden. Verificá:

```bash
# Está escuchando?
netstat -ano | grep 5432

# Podés conectar?
psql -h localhost -U pianovision -d pianovision
```

### Web: errores de tipos al compilar

Después de cambiar dependencias, limpiar caches:

```bash
cd web
rm -rf .angular dist node_modules
npm install
npm start
```

### Mobile: emulador no aparece en `flutter devices`

```bash
flutter emulators --launch <id>          # lanzar emulador
adb devices                              # verificar que adb lo vea
flutter devices                          # debería aparecer ahora
```

Si está como "offline", esperar que termine de bootear (puede tardar 1-2 min).

### Mobile: app no conecta al backend desde el emulador Android

Los emuladores Android **no acceden a `localhost` del host**. Usar `10.0.2.2` — esto ya está en [mobile/lib/core/config/app_config.dart:29](mobile/lib/core/config/app_config.dart#L29). Si seguís viendo errores de conexión, verificar:

1. Que el backend esté corriendo en `0.0.0.0:8000` (no `127.0.0.1`).
2. Que el archivo [mobile/android/app/src/debug/AndroidManifest.xml](mobile/android/app/src/debug/AndroidManifest.xml) tenga `networkSecurityConfig` apuntando a `network_security_config.xml` (para permitir HTTP en debug).

### Despliegue: el deploy falló a mitad

```bash
ssh user@vm-ip
cd ~/pianovision
docker compose --env-file .env.production logs --tail 100
docker compose --env-file .env.production ps        # ver estado
docker compose --env-file .env.production restart   # reintentar
```

---

## Estructura del proyecto

```
PianoVision/
├── README.md
├── .gitignore
│
├── backend/                       # FastAPI (lo que tocás en dev)
│   ├── app/                       # código fuente (api, core, crud, models, schemas, services)
│   ├── alembic/                   # migraciones DB
│   ├── tests/
│   ├── seed_*.py                  # scripts de seed (corren en cada deploy)
│   ├── Dockerfile                 # multi-stage (CI lo usa para build)
│   ├── .dockerignore
│   ├── entrypoint.sh              # migraciones + start uvicorn
│   ├── alembic.ini                # config Alembic
│   ├── pyproject.toml             # config pytest + ruff
│   ├── requirements.txt
│   ├── requirements-test.txt
│   └── .env                       # NO commitear
│
├── web/                           # Angular admin (lo que tocás en dev)
│   ├── src/app/
│   │   ├── core/                  # servicios, interceptors, guards
│   │   ├── features/              # módulos por feature
│   │   └── shared/                # componentes compartidos
│   ├── public/                    # assets estáticos
│   ├── nginx.conf                 # nginx interno del container web
│   ├── eslint.config.js
│   ├── Dockerfile                 # CI lo usa para build
│   └── .dockerignore
│
├── mobile/                        # Flutter (lo que tocás en dev)
│   ├── lib/
│   │   ├── core/                  # config, network, theme
│   │   └── features/              # screens y blocs por feature
│   ├── android/ ios/ web/         # plataformas
│   ├── test/
│   └── analysis_options.yaml
│
├── infra/                         # ⚙️ Infraestructura — solo producción
│   ├── docker-compose.yml         # orquesta containers en la VM
│   └── nginx/                     # reverse proxy + SSL
│       ├── nginx.conf
│       └── conf.d/
│
├── docs/                          # arquitectura y decisiones
│   └── ARCHITECTURE.md            # diagramas Mermaid, flujos, trade-offs
│
└── .github/workflows/             # CI/CD
    └── deploy.yml                 # build + push a Artifact Registry + deploy a VM
```

---

## Convenciones

- **Backend**: Pydantic v2 para schemas, SQLAlchemy 2 async, dependencias inyectadas vía `Depends()`.
- **Web**: Angular 21 standalone components + signals, sin NgModules. Servicios en `core/`, features lazy-loaded.
- **Mobile**: BLoC pattern (`flutter_bloc`), Dio para HTTP, GoRouter para navegación.
- **Commits**: Convencional (`feat:`, `fix:`, `chore:`, `docs:`, `ci:`).
- **Branches**: `main` despliega automáticamente. Feature branches → PR a `main`.
