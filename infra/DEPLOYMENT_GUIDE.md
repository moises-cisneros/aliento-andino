# Guía de Despliegue e Infraestructura Adaptable — Aliento Andino

Esta guía define las estrategias de despliegue para **Aliento Andino**, diseñada bajo un principio de **Arquitectura Cloud-Agnostic**. La plataforma puede operar indistintamente en dos topologías según el presupuesto, escala y requisitos del entorno:

1. **Topología A (Monolítica VPS)**: Todos los servicios orquestados en un único servidor mediante Docker Compose y Nginx.
2. **Topología B (Distribuida Multi-Cloud / Serverless)**: Cada componente desplegado de forma independiente en proveedores PaaS, Serverless y Jamstack especializados.

---

## Comparativa de Topologías

| Criterio          | Topología A: VPS Unificado                                | Topología B: Multi-Cloud Distribuido                               |
| :---------------- | :-------------------------------------------------------- | :----------------------------------------------------------------- |
| **Costo inicial** | Muy bajo (desde \$4-\$10/mes en Hetzner o DigitalOcean)   | Tier gratuito generoso (Cloudflare + Render + Neon + GitHub Pages) |
| **Mantenimiento** | Requiere administración de SO, Docker y backups           | Cero mantenimiento de SO (servicios administrados)                 |
| **Escalabilidad** | Vertical (ampliar RAM/CPU de la VPS)                      | Horizontal independiente por servicio                              |
| **Complejidad**   | Centralizada (un solo `docker compose up -d`)             | Distribuida (configuraciones por plataforma)                       |
| **Casos de uso**  | Desarrollo, servidores institucionales, academias locales | Producción global, alta concurrencia, tolerancia a fallos          |

---

## Topología A: Despliegue Todo-en-Uno en VPS

En esta topología, la máquina virtual ejecuta todos los servicios contenerizados comunicados a través de una red interna aislada. El contenedor `nginx` actúa como el perímetro seguro hacia Internet.

```
                         [ Internet (HTTPS :443 / HTTP :80) ]
                                          │
                                   ┌──────▼──────┐
                                   │    Nginx    │ (Perímetro + Certbot SSL)
                                   └──────┬──────┘
                   ┌──────────────────────┼──────────────────────┐
                   │ /                    │ /api/                │ /manual/
            ┌──────▼──────┐        ┌──────▼──────┐        ┌──────▼──────┐
            │  web (SPA)  │        │   backend   │        │ docs (Docs) │
            │ (Angular)   │        │  (FastAPI)  │        │ (Docusaurus)│
            └─────────────┘        └──────┬──────┘        └─────────────┘
                                          │
                   ┌──────────────────────┴──────────────────────┐
                   │                                             │
            ┌──────▼──────┐                               ┌──────▼──────┐
            │     db      │                               │  ml-service │
            │(Postgres 16)│                               │ (Inferencia)│
            └─────────────┘                               └─────────────┘
```

### 1. Requisitos Previos del VPS

- Sistema Operativo: Ubuntu 22.04 LTS o Debian 12.
- Recursos mínimos: 2 vCPU, 4 GB RAM, 30 GB SSD.
- Docker Engine $\ge 24.0$ y Docker Compose $\ge 2.20$.
- Dominio DNS apuntando con registros `A` a la IP pública del VPS (ej: `alientoandino.org`).

### 2. Configuración de Variables de Entorno

Crea el archivo `.env.production` en la raíz del servidor:

```env
# Base de datos
POSTGRES_USER=aliento_prod_user
POSTGRES_PASSWORD=genera_una_clave_segura_de_32_caracteres
POSTGRES_DB=aliento_andino_prod

# Backend FastAPI
SECRET_KEY=clave_secreta_jwt_criptografica_minimo_64_bits
GOOGLE_CLIENT_ID=tu-id-de-cliente.apps.googleusercontent.com
CORS_ORIGINS=["https://alientoandino.org"]
FRONTEND_URL=https://alientoandino.org
DEBUG=false

# Correo SMTP (notificaciones y bienvenida)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=notificaciones@alientoandino.org
SMTP_PASSWORD=tu-app-password-de-google
SMTP_FROM_EMAIL=notificaciones@alientoandino.org

# Nginx y SSL
DOMAIN=alientoandino.org
CERTBOT_EMAIL=admin@alientoandino.org
```

### 3. Arranque del Stack

```bash
# 1. Clonar el repositorio en el servidor
git clone https://github.com/moises-cisneros/aliento-andino.git /opt/aliento-andino
cd /opt/aliento-andino

# 2. Levantar el stack completo con Docker Compose
docker compose -f infra/docker-compose.yml --env-file .env.production up -d --build

# 3. Ejecutar migraciones iniciales de base de datos
docker compose -f infra/docker-compose.yml exec backend alembic upgrade head

# 4. Poblar datos semilla iniciales (instrumentos y lecciones)
docker compose -f infra/docker-compose.yml exec backend python seed_all.py
```

### 4. Certificado SSL con Certbot

Nginx termina TLS en el puerto 443 y **no arranca sin el certificado**. Emitirlo la primera vez con el modo `standalone` (puerto 80 libre) y luego levantar el stack:

```bash
docker compose -f infra/docker-compose.yml run --rm -p 80:80 certbot certonly   --standalone   -d alientoandino.org -d www.alientoandino.org   --email admin@alientoandino.org --agree-tos --no-eff-email

docker compose -f infra/docker-compose.yml up -d
```

Las renovaciones usan el webroot `/var/www/certbot` que Nginx ya expone en `/.well-known/acme-challenge/`:

```bash
docker compose -f infra/docker-compose.yml run --rm certbot renew --webroot -w /var/www/certbot
docker compose -f infra/docker-compose.yml exec nginx nginx -s reload
```

### 5. Perímetro Nginx (SSL, rate limiting y cabeceras)

Configuración en [`infra/nginx/nginx.conf`](nginx/nginx.conf):

| Control                | Detalle                                                                                                   |
| :--------------------- | :-------------------------------------------------------------------------------------------------------- |
| Terminación TLS        | Solo TLS 1.2/1.3 con suites AEAD, HTTP/2, `ssl_session_tickets off`. El puerto 80 redirige (301) a HTTPS. |
| Cabeceras de seguridad | `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, HSTS (2 años), CSP y `Referrer-Policy`.       |
| Rate limiting          | `/api/auth/`: 10 req/s por IP (burst 5). Resto de `/api/`: 20 req/s; web: 30 req/s; ML: 15 req/s.         |
| Tráfico excedente      | Nginx responde `429 Too Many Requests` sin llegar al backend (`limit_req_status 429`).                    |
| Compresión             | `gzip` para texto, JSON, JavaScript, CSS, SVG y manifests (>1 KB).                                        |
| Health check           | `GET /health` (HTTP y HTTPS) proxied al backend; objetivo < 20 ms. Compose lo usa como `healthcheck`.     |

Verificación local (requiere Docker; genera un certificado autofirmado y un upstream de prueba):

```bash
bash infra/nginx/tests/run.sh
```

Cubre `nginx -t` (unitaria), redirección HTTP→HTTPS y ráfaga contra `/api/auth/` con respuestas `429` (integración) y cabeceras, gzip y latencia de `/health` sobre HTTPS (E2E). Se ejecuta en CI cuando cambia `infra/nginx/` o `infra/docker-compose.yml`. La calificación **A en SSL Labs** se comprueba manualmente tras el despliegue en <https://www.ssllabs.com/ssltest/>.

---

## Topología B: Despliegue Distribuido Multi-Cloud (PaaS / Serverless)

En esta topología, ningún servicio comparte máquina física con otro. Cada capa corre en la plataforma óptima para su naturaleza técnica:

> **Estado de implementación**: esta topología es una guía de referencia; el repositorio incluye `render.yaml` (backend y ML en Render) pero aún no `vercel.json`, `wrangler.toml` ni configuración de Supabase. La única automatización de despliegue existente es `.github/workflows/deploy.yml` (imágenes a GCP Artifact Registry y despliegue por SSH a una VM, ver Topología A) y `.github/workflows/docs.yml` (manual en GitHub Pages).
>
> **Herramientas de operación**: CLI `render` y `vercel`; MCP de Neon y plugin MCP de Render (requieren autenticación); `wrangler` (Cloudflare), `neonctl` y `supabase` deben instalarse antes de usarlos. Cloudflare D1 no sirve como base de datos (es SQLite y los modelos SQLAlchemy/Alembic son PostgreSQL). El servicio ML escucha en el puerto 8001 del contenedor (8051 en el host por defecto) y nunca debe recibir audio ni video crudos.

### 1. Panel Administrativo Web (`apps/web`) -> Cloudflare Pages / Vercel

- **Plataforma recomendada**: Cloudflare Pages (Ancho de banda ilimitado y protección DDoS global).
- **Configuración de Build**:
  - Build command: `pnpm --filter web run build`
  - Build output directory: `apps/web/dist/web/browser`
  - Node.js Version: `22`
  - Variable de entorno en Cloudflare:
    - `API_BASE_URL`: `https://api.alientoandino.org`

#### Despliegue en Vercel (activo)

- **Proyecto**: `aliento-andino-web` (plan Hobby). URL: `https://aliento-andino-web.vercel.app`.
- **Configuración**: `apps/web/vercel.json` (install `pnpm install --frozen-lockfile`, build `pnpm build`, salida `dist/web/browser`).
- **Backend (único lugar a cambiar)**: el rewrite `/api/:path*` de `apps/web/vercel.json` apunta al marcador `https://aliento-andino-backend.onrender.com/api/:path*`. Al desplegar el backend con otra URL, edítese solo ese `destination`. El fallback SPA (`/(.*)` -> `/index.html`) va después.
- **CORS**: el backend debe incluir `https://aliento-andino-web.vercel.app` en `CORS_ORIGINS`.
- **Despliegue manual**: `cd apps/web && vercel deploy --prod --yes` (el directorio `.vercel/` está ignorado por git).

### 2. Manual de Usuario Oficial (`apps/docs`) -> GitHub Pages

- **Plataforma recomendada**: GitHub Pages (Integrado directamente mediante el repositorio).
- **Workflow automatizado**: `.github/workflows/docs.yml` compila Docusaurus y despliega la rama `gh-pages` en cada push a `main`.
- **URL Pública**: `https://moises-cisneros.github.io/aliento-andino/`

### 3. API REST Central (`apps/backend`) -> Render / Google Cloud Run / Railway

- **Plataforma recomendada**: Render Web Service (o Google Cloud Run para escalado a cero).
- **Tipo de entorno**: Dockerfile (`apps/backend/Dockerfile`).
- **Variables de Entorno requeridas**:
  - `DATABASE_URL`: URL de conexión provista por Neon o Supabase (`postgresql+asyncpg://...`).
  - `SECRET_KEY`: Llave de firma JWT.
  - `CORS_ORIGINS`: `["https://admin.alientoandino.org","https://alientoandino.org"]`
  - `GOOGLE_CLIENT_ID`: Credencial OAuth.
- **Blueprint**: `render.yaml` (raíz) define `aliento-andino-backend` (plan free, región Ohio, health check `/health`, puerto 8000). `SECRET_KEY` se genera automáticamente; `DATABASE_URL` y `CORS_ORIGINS` se cargan manualmente (`sync: false`).
- **Migraciones**: `entrypoint.sh` ejecuta `alembic upgrade head` en cada arranque. Con el pooler de Neon (PgBouncer) pueden fallar; usá la URL directa para la primera migración.

#### Despliegue en Google Cloud Run (activo, en paralelo a Render)

El backend y el microservicio ML también corren en GCP. Ambos despliegues conviven y **comparten la misma base de Neon**; el tráfico de la web y del móvil sigue yendo a Render hasta completar la reconexión descrita más abajo.

- **Proyecto**: `aliento-andino-prod`, región `us-central1` (región elegible para la capa gratuita).
- **Servicios** (se despliegan desde el `Dockerfile` de cada app, sin imagen previa):

  | Servicio          | URL                                                        | Recursos                         |
  | :---------------- | :--------------------------------------------------------- | :------------------------------- |
  | `aliento-backend` | `https://aliento-backend-788250326019.us-central1.run.app` | 512 MiB, 0 a 2 instancias, :8000 |
  | `aliento-ml`      | `https://aliento-ml-788250326019.us-central1.run.app`      | 1 GiB, 0 a 1 instancia, :8001    |

- **Secretos** (Secret Manager, montados como variables): `DATABASE_URL` (URL directa asyncpg de Neon, igual que en Render) y `SECRET_KEY`. `CORS_ORIGINS` y `FRONTEND_URL` son variables de entorno normales; como `CORS_ORIGINS` lleva comas, en `--set-env-vars` hay que declarar otro delimitador (`^@^`).
- **Comandos**:

  ```bash
  gcloud run deploy aliento-backend --source apps/backend --project aliento-andino-prod --region us-central1     --port 8000 --allow-unauthenticated --min-instances 0 --max-instances 2 --memory 512Mi     --command ./entrypoint.sh --args "uvicorn,app.main:app,--host,0.0.0.0,--port,8000,--workers,1"     --set-secrets "DATABASE_URL=DATABASE_URL:latest,SECRET_KEY=SECRET_KEY:latest"     --set-env-vars "^@^CORS_ORIGINS=<origen1>,<origen2>@FRONTEND_URL=<url del front>"

  gcloud run deploy aliento-ml --source apps/ml --project aliento-andino-prod --region us-central1     --port 8001 --allow-unauthenticated --min-instances 0 --max-instances 1 --memory 1Gi
  ```

- **Verificación**: `gcloud run services list --project aliento-andino-prod` y `GET /health` en cada URL. Cloud Run no aparece en `gcloud compute instances list`, que solo lista máquinas virtuales.
- **Límites**: un solo worker de uvicorn para respetar los 512 MiB (el `CMD` del Dockerfile usa 4). Arranque en frío de unos segundos con `--min-instances 0`.
- **Pendiente en esta copia**: `GOOGLE_CLIENT_ID` no está configurado, así que el inicio de sesión con Google no funciona hasta cargarlo.

#### Reconexión al reemplazar Render por Cloud Run

Cambiar de proveedor no es solo "bajar uno y subir otro": hay piezas que apuntan al backend de Render y deben actualizarse. Estos son todos los puntos de conexión del repositorio:

| Pieza que apunta al backend | Dónde                                                    | Qué cambiar                                                                                                                    |
| :-------------------------- | :------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------- |
| Panel web (Vercel)          | `apps/web/vercel.json` (rewrite `/api`)                  | `destination` a `https://aliento-backend-788250326019.us-central1.run.app/api/:path*` y volver a desplegar la web.             |
| App móvil                   | `--dart-define=API_BASE_URL=...`                         | Compilar una nueva versión con `API_BASE_URL=https://aliento-backend-788250326019.us-central1.run.app/api`.                    |
| CORS del backend            | Variable `CORS_ORIGINS` del servicio                     | Sin cambios: los orígenes del front (web) no se mueven. Solo debe estar cargada en Cloud Run.                                  |
| Keep-alive                  | `TARGETS` en `infra/cloudflare-keepalive/wrangler.jsonc` | Reemplazar las URLs `onrender.com` por las de Cloud Run o quitarlas: Cloud Run factura por solicitud y no necesita keep-alive. |
| Microservicio ML            | Ninguna                                                  | Ni el backend ni la app lo referencian por configuración; solo cambia su URL pública.                                          |
| Blueprint de Render         | `render.yaml`                                            | Queda como referencia; no se borra.                                                                                            |

**Orden recomendado** (sin tiempo de caída, porque ambos backends usan la misma base):

1. Comprobar `GET /health` en ambos servicios de Cloud Run.
2. Cambiar el `destination` de `apps/web/vercel.json` y desplegar la web (`cd apps/web && vercel deploy --prod --yes`).
3. Probar el inicio de sesión desde la web.
4. Publicar la nueva compilación móvil. **Mantener Render encendido** mientras haya instalaciones con la URL anterior.
5. Actualizar `TARGETS` y desplegar el Worker (`npx wrangler deploy`).
6. Suspender (no eliminar) los servicios de Render.

**Reversión**: volver a poner el `destination` de Render en `vercel.json` y redesplegar la web.

**Advertencias**:

- Ambos backends ejecutan `alembic upgrade head` al arrancar sobre la misma base. Durante la transición no desplegar versiones distintas del código en cada proveedor.
- Cada despliegue tiene su propio `SECRET_KEY`: los tokens emitidos por uno no valen en el otro, y los usuarios deberán iniciar sesión de nuevo al cambiar.

### 4. Base de Datos Relacional -> Neon Serverless Postgres / Supabase

- **Plataforma recomendada**: Neon (PostgreSQL 16 nativo con autoscaling y branching de base de datos para staging).
- **Configuración**:
  - Habilitar Connection Pooling (PgBouncer) para absorber picos de conexiones de clientes concurrentes.
  - Conexión segura obligatoria (`sslmode=require`).

### 5. Microservicio de Inferencia Acústica (`apps/ml`) -> Render / RunPod Serverless

- **Plataforma recomendada**: Render Background/Web Service o RunPod.
- **Tipo de entorno**: Dockerfile (`apps/ml/Dockerfile`).
- Expone el puerto `8001` con endpoints `/health` y matching semántico.
- Definido como `aliento-andino-ml` en `render.yaml` (plan free, región Ohio, `PORT=8001`).
- También desplegado en Google Cloud Run como `aliento-ml` (ver el apartado de la API REST).

### 6. Aplicación Móvil (`apps/mobile`) -> Google Play / App Store

- Inferencia de Pitch (YIN/SPICE), visión postural (MediaPipe) y tutor SLM **corren 100% on-device** en el cliente del estudiante.
- Se comunica vía HTTPS únicamente con `https://api.alientoandino.org` para sincronización de progreso, ranking social y autenticación.

### 5. Keep-alive de servicios free-tier -> Cloudflare Worker (Cron Trigger)

Los web services gratuitos de Render se duermen tras ~15 min sin tráfico. El Worker `aliento-keepalive` (`infra/cloudflare-keepalive/`) los consulta cada 10 minutos (`*/10 * * * *`, plan gratuito de Cloudflare) con `GET` y `User-Agent: aliento-keepalive`, timeout de 10 s.

- **Targets**: variable `TARGETS` (URLs completas separadas por comas) en `infra/cloudflare-keepalive/wrangler.jsonc`. Salud del backend: `/health`; del ML: `/health` (puerto 8001 en el contenedor). Ejemplo: `https://<backend>.onrender.com/health,https://<ml>.onrender.com/health`.
- **Despliegue**: `cd infra/cloudflare-keepalive && pnpm install && npx wrangler deploy` (requiere `npx wrangler login` o `CLOUDFLARE_API_TOKEN`).
- **Verificación**: `GET` a la URL `workers.dev` del Worker devuelve el JSON con los últimos resultados; `npx wrangler tail` muestra los logs del cron.
- **Pruebas**: `pnpm test` en el mismo directorio.

---

## Comandos Unificados de Gestión (`package.json`)

Para garantizar que cualquier desarrollador pueda operar el proyecto sin fricción, se proveen comandos estandarizados en la raíz:

```bash
# --- Docker: Levantar Todo el Stack ---
pnpm dev              # Inicia todos los servicios en segundo plano (docker compose up -d)
pnpm dev:build        # Reconstruye y levanta imágenes (docker compose up -d --build)
pnpm dev:down         # Detiene y remueve contenedores
pnpm dev:logs         # Visualiza logs en tiempo real

# --- Docker: Levantar Servicios de Forma Independiente ---
pnpm docker:db        # Solo PostgreSQL
pnpm docker:backend   # Solo API FastAPI
pnpm docker:web       # Solo Panel Angular Web
pnpm docker:docs      # Solo Manual Docusaurus
pnpm docker:ml        # Solo Microservicio ML
pnpm docker:nginx     # Solo Reverse Proxy

# --- Ejecución Local en Host (Sin Docker) ---
pnpm dev:backend:host # Backend en http://localhost:8000
pnpm dev:web:host     # Angular en http://localhost:4200
pnpm dev:docs:host    # Docusaurus en http://localhost:3001
pnpm dev:ml:host      # Microservicio ML en http://localhost:8001
pnpm dev:mobile:host  # Flutter en emulador o dispositivo físico
```

---

## Políticas de Backup y Recuperación (Disaster Recovery)

1. **RPO (Recovery Point Objective)**: Menor a 24 horas (respaldo diario a las 03:00 UTC).
2. **RTO (Recovery Time Objective)**: Menor a 30 minutos para restauración completa de base de datos desde dump comprimido `.sql.gz`.
3. **Automatización**: Ejecución programada mediante `infra/backup/aliento-andino-backup.service` y `infra/backup/aliento-andino-backup.timer` con subida automática a Object Storage (GCS / AWS S3 / Cloudflare R2).
