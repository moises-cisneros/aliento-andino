# Tunnel Proxy — Aliento Andino

Túnel persistente con reconexión automática y detección de salud de puerto local para pruebas de desarrollo móvil y webhooks.

## ¿Para qué sirve?

Permite exponer el backend local (por defecto `localhost:8050`) o el reverse proxy Nginx (`localhost:80`) a una URL pública HTTPS (`https://<subdominio>.loca.lt`) sin necesidad de tocar configuración del router, abrir puertos ni depender de que el móvil esté conectado a la misma red Wi-Fi o por cable USB.

### Casos de uso principales

1. **Uso local con servicios locales (Móvil físico sin cables ni Wi-Fi compartida):**
   - El backend corre localmente en tu computadora.
   - El túnel genera una URL HTTPS pública (ej. `https://aliento-andino-dev.loca.lt`).
   - La aplicación móvil en tu teléfono físico (incluso usando datos móviles 4G/5G) se conecta directamente al backend:
     ```bash
     flutter run --dart-define=API_BASE_URL=https://aliento-andino-dev.loca.lt/api
     ```

2. **Uso local con servicios en la nube (Webhooks, OAuth callbacks y testing híbrido):**
   - Servicios de terceros en la nube (ej. Google OAuth Redirects, pasarelas de pago, webhooks externos) pueden enviar peticiones directamente a tu backend local a través de la URL del túnel.
   - Permite depurar endpoints locales recibiendo eventos reales de la nube en tiempo real.

## Uso

Desde la raíz del monorepo:

```bash
# Iniciar el túnel
pnpm tunnel

# O en modo desarrollo con auto-reload
pnpm dev:tunnel
```

O desde el directorio de la herramienta:

```bash
cd tools/tunnel-proxy
pnpm install
pnpm start
```

## Configuración (`.env`)

Copia `.env.example` a `.env` si querés personalizar el puerto o subdominio:

| Variable                | Descripción                                         | Valor por defecto    |
| :---------------------- | :-------------------------------------------------- | :------------------- |
| `LOCAL_PORT`            | Puerto local a exponer (`8050` backend, `80` Nginx) | `8050`               |
| `LOCAL_HOST`            | Host local                                          | `localhost`          |
| `SUBDOMAIN`             | Subdominio deseado (ej. `aliento-andino-dev`)       | `aliento-andino-dev` |
| `RECONNECT_DELAY`       | Tiempo entre reintentos en ms                       | `5000`               |
| `HEALTH_CHECK_INTERVAL` | Intervalo de verificación en ms                     | `30000`              |
