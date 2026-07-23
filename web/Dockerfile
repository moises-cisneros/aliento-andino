# === Dockerfile para Angular Web Admin Panel ===

# --- Etapa 1: Build ---
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm run build -- --configuration production

# --- Etapa 2: Servir con Nginx ---
FROM nginx:alpine

# Copiar build de Angular al directorio de Nginx
COPY --from=builder /app/dist/web/browser /usr/share/nginx/html

# Configuración de Nginx para SPA (Angular routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
