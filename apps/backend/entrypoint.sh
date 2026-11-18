#!/bin/sh
set -e

echo "Running database migrations..."
alembic upgrade head

if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "Provisioning initial admin from environment variables..."
    python create_admin.py || echo "Warning: create_admin failed"
fi

echo "Starting server..."
exec "$@"