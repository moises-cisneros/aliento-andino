# Backups de Postgres → GCS

## Setup en la VM (una sola vez)

```bash
# 1. Subir los archivos
gcloud compute scp infra/backup/pg_backup.sh pianovision-vm:/tmp/ --zone=us-central1-a
gcloud compute scp infra/backup/pianovision-backup.service pianovision-vm:/tmp/ --zone=us-central1-a
gcloud compute scp infra/backup/pianovision-backup.timer pianovision-vm:/tmp/ --zone=us-central1-a

# 2. Conectar a la VM
gcloud compute ssh pianovision-vm --zone=us-central1-a

# Dentro de la VM:
sudo install -m 755 /tmp/pg_backup.sh /usr/local/bin/pg_backup.sh
sudo cp /tmp/pianovision-backup.service /etc/systemd/system/
sudo cp /tmp/pianovision-backup.timer /etc/systemd/system/

# 3. Configurar variables
sudo mkdir -p /etc/pianovision
sudo tee /etc/pianovision/backup.env > /dev/null <<EOF
POSTGRES_USER=pianovision
POSTGRES_DB=pianovision
GCS_BUCKET=pianovision-backups
DB_CONTAINER=pianovision-db-1
EOF
sudo chmod 600 /etc/pianovision/backup.env

# 4. Habilitar el timer
sudo systemctl daemon-reload
sudo systemctl enable --now pianovision-backup.timer

# 5. Probar manualmente
sudo systemctl start pianovision-backup.service
sudo journalctl -u pianovision-backup.service -n 50
```

## Restore desde un backup

```bash
# Listar backups disponibles
gcloud storage ls gs://pianovision-backups/

# Descargar uno
gcloud storage cp gs://pianovision-backups/pianovision-20260524-030000.sql.gz /tmp/

# Restaurar
gunzip -c /tmp/pianovision-20260524-030000.sql.gz | \
  docker exec -i pianovision-db-1 psql -U pianovision -d pianovision
```

## Retención

El bucket tiene una **lifecycle rule** que borra automáticamente los objetos con más de 30 días.
