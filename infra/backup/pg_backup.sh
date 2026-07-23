#!/bin/bash
# Backup diario de Postgres a Google Cloud Storage.
# Diseñado para correr en la VM `pianovision-vm` via systemd timer.
#
# Requisitos:
# - gcloud CLI con default SA (compute@) con rol storage.objectAdmin sobre el bucket
# - postgres corriendo en contenedor docker `pianovision-db` (compose service "db")
# - Variables en /etc/pianovision/backup.env: POSTGRES_USER, POSTGRES_DB, GCS_BUCKET

set -euo pipefail

CONFIG_FILE="${BACKUP_CONFIG:-/etc/pianovision/backup.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

POSTGRES_USER="${POSTGRES_USER:?missing POSTGRES_USER}"
POSTGRES_DB="${POSTGRES_DB:?missing POSTGRES_DB}"
GCS_BUCKET="${GCS_BUCKET:-pianovision-backups}"
DB_CONTAINER="${DB_CONTAINER:-pianovision-db-1}"  # nombre por defecto con compose v2

TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
DUMP_FILE="/tmp/pianovision-${TIMESTAMP}.sql.gz"

echo "[backup] $(date -u +%FT%TZ) Iniciando dump de $POSTGRES_DB"

docker exec "$DB_CONTAINER" pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --no-owner --no-privileges --clean --if-exists \
  | gzip -9 > "$DUMP_FILE"

SIZE=$(du -h "$DUMP_FILE" | cut -f1)
echo "[backup] Dump completado ($SIZE)"

gsutil cp "$DUMP_FILE" "gs://$GCS_BUCKET/$(basename "$DUMP_FILE")"
echo "[backup] Subido a gs://$GCS_BUCKET/$(basename "$DUMP_FILE")"

rm -f "$DUMP_FILE"
echo "[backup] OK"
