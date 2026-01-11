#!/bin/bash

# Mikrus Toolbox - Listmonk
# High-performance self-hosted newsletter and mailing list manager.
# Alternative to Mailchimp / MailerLite.
# Written in Go - very lightweight.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="listmonk"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=9000

echo "--- 📧 Listmonk Setup ---"
echo "Requires PostgreSQL Database."

# Database credentials (from environment or prompt)
if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
    echo "✅ Używam danych bazy z konfiguracji:"
    echo "   Host: $DB_HOST | User: $DB_USER | DB: $DB_NAME"
    DB_PORT=${DB_PORT:-5432}
else
    echo "📝 Podaj dane bazy PostgreSQL:"
    read -p "Database Host: " DB_HOST
    read -p "Database Name: " DB_NAME
    read -p "Database User: " DB_USER
    read -s -p "Database Password: " DB_PASS
    echo ""
fi
# Domain (from environment or prompt)
if [ -n "$DOMAIN" ]; then
    echo "✅ Używam domeny z konfiguracji: $DOMAIN"
else
    echo ""
    read -p "Domain (e.g., mail.example.com): " DOMAIN
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Listmonk needs an initial install step to create tables
# We use docker-compose but with a one-time install flag if it's the first run.

cat <<EOF | sudo tee docker-compose.yaml

services:
  listmonk:
    image: listmonk/listmonk:latest
    restart: always
    ports:
      - "$PORT:9000"
    environment:
      - TZ=Europe/Warsaw
      - LISTMONK_db__host=$DB_HOST
      - LISTMONK_db__port=$DB_PORT
      - LISTMONK_db__user=$DB_USER
      - LISTMONK_db__password=$DB_PASS
      - LISTMONK_db__database=$DB_NAME
      - LISTMONK_app__address=0.0.0.0:9000
      - LISTMONK_app__root_url=https://$DOMAIN
    volumes:
      - ./data:/listmonk/uploads
    deploy:
      resources:
        limits:
          memory: 256M

EOF

# 1. Run Install (Migrate DB)
echo "Running database migrations..."
sudo docker compose run --rm listmonk ./listmonk --install --yes || echo "Migrations already done or failed."

# 2. Start Service
sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 60 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Kontener działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo ""
echo "✅ Listmonk started at https://$DOMAIN"
echo "Default user: admin / listmonk"
echo "👉 CONFIGURE YOUR SMTP SERVER IN SETTINGS TO SEND EMAILS."
