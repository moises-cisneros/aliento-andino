# === Dockerfile multi-stage para Aliento Andino Web Admin Panel (Angular 21) ===

# --- Etapa 1: Build ---
FROM node:22-alpine AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@10.28.2 --activate

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile || pnpm install

COPY . .
RUN pnpm run build --configuration production

# --- Etapa 2: Servir con Nginx ---
FROM nginx:alpine

# Copiar artefactos compilados de Angular al directorio de Nginx
COPY --from=builder /app/dist/web/browser /usr/share/nginx/html

# Configuración de Nginx para SPA (Angular routing). Se instala como plantilla:
# la imagen oficial de nginx sustituye ${BACKEND_UPSTREAM} al arrancar.
# Por defecto apunta al servicio `backend` de Docker Compose; en Cloud Run se
# define con la URL pública del backend (https://<servicio>.run.app).
COPY nginx.conf /etc/nginx/templates/default.conf.template
ENV BACKEND_UPSTREAM=http://backend:8000

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
