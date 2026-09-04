# === Dockerfile multi-stage para PianoVision AI API ===

# --- Etapa 1: Builder ---
FROM python:3.12-slim AS builder

WORKDIR /app

# Instalar dependencias del sistema para compilar paquetes
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copiar e instalar dependencias Python
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- Etapa 2: Producción ---
FROM python:3.12-slim

WORKDIR /app

# Copiar dependencias instaladas desde builder
COPY --from=builder /install /usr/local

# Copiar código fuente
COPY . .

# Asegurar saltos de línea LF y hacer ejecutable el entrypoint
RUN sed -i 's/\r$//' entrypoint.sh && chmod +x entrypoint.sh

# Crear usuario no-root para seguridad
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# Exponer puerto
EXPOSE 8000

# Entrypoint: migraciones + inicio
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
