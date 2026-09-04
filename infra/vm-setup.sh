#!/bin/bash
# ============================================
# PianoVision VM Setup Script
# Ejecutar en la VM después de crearla via SSH
# Proyecto: melodypath-499801
# ============================================
set -e

echo "=== [1/5] Instalando Docker ==="
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
echo "Docker instalado OK"

echo "=== [2/5] Instalando gcloud CLI ==="
curl https://sdk.cloud.google.com | bash -s -- --disable-prompts
source "$HOME/.bashrc" 2>/dev/null || true
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
echo "gcloud instalado OK"

echo "=== [3/5] Autenticando gcloud con el proyecto ==="
gcloud config set project melodypath-499801
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
echo "gcloud configurado OK"

echo "=== [4/5] Creando estructura de directorios ==="
mkdir -p ~/pianovision/nginx/conf.d
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMnrzihUVPAH9EUi1/i5NUwnmiWGi4/S5l0onCuFvplP pianovision-github-actions" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "SSH key de GitHub Actions agregada OK"

echo "=== [5/5] Creando .env.production ==="
cat > ~/pianovision/.env.production << 'ENVEOF'
POSTGRES_USER=pianovision
POSTGRES_PASSWORD=Pv2026!xK9mQr3Zn
POSTGRES_DB=pianovision
SECRET_KEY=j9PJs5e9WlVVXJs6GFldSa0MrIPRja4acB7o6MZ+KqwAi+69mWY4qjhe1GIO+jxA
GOOGLE_CLIENT_ID=PENDIENTE_REEMPLAZAR
DOCKER_REGISTRY=us-central1-docker.pkg.dev/melodypath-499801/pianovision
IMAGE_TAG=latest
VERTEX_PROJECT_ID=melodypath-499801
VERTEX_LOCATION=us-central1
GEMINI_MODEL=gemini-2.5-flash
CORS_ORIGINS=["http://REEMPLAZAR_IP"]
FRONTEND_URL=http://REEMPLAZAR_IP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=fernando.fa671@gmail.com
SMTP_PASSWORD=PENDIENTE_APP_PASSWORD_GMAIL
SMTP_FROM_NAME=PianoVision AI
SMTP_FROM_EMAIL=fernando.fa671@gmail.com
DEBUG=false
ENVEOF

echo "============================================"
echo "  VM Setup completado!"
echo "  IP de esta VM: $(curl -s ifconfig.me)"
echo "  Edita ~/pianovision/.env.production"
echo "  Reemplaza REEMPLAZAR_IP y GOOGLE_CLIENT_ID"
echo "============================================"
newgrp docker
