#!/bin/bash

# Mikrus Toolbox - NocoDB
# Open Source Airtable alternative.
# Connects to your own database and turns it into a spreadsheet.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="nocodb"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=8080

echo "--- 📅 NocoDB Setup ---"
echo "We recommend using External PostgreSQL."

# Database credentials (from environment or prompt)
if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
    echo "✅ Używam danych bazy z konfiguracji:"
    echo "   Host: $DB_HOST | User: $DB_USER | DB: $DB_NAME"
    DB_PORT=${DB_PORT:-5432}
    DB_URL="pg://$DB_HOST:$DB_PORT?u=$DB_USER&p=$DB_PASS&d=$DB_NAME"
else
    read -p "Database Host (or press Enter for internal SQLite - not recommended): " DB_HOST
    if [ -n "$DB_HOST" ]; then
        read -p "Database Name: " DB_NAME
        read -p "Database User: " DB_USER
        read -s -p "Database Password: " DB_PASS
        echo ""
        DB_URL="pg://$DB_HOST:5432?u=$DB_USER&p=$DB_PASS&d=$DB_NAME"
    else
        echo "Using internal SQLite (Warning: Higher RAM usage on host)"
        DB_URL=""
    fi
fi
# Domain (from environment or prompt)
if [ -n "$DOMAIN" ]; then
    echo "✅ Używam domeny z konfiguracji: $DOMAIN"
else
    echo ""
    read -p "Domain (e.g., db.example.com): " DOMAIN
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml

services:
  nocodb:
    image: nocodb/nocodb:latest
    restart: always
    ports:
      - "$PORT:8080"
    environment:
      - NC_DB=$DB_URL
      - NC_PUBLIC_URL=https://$DOMAIN
    volumes:
      - ./data:/usr/app/data
    deploy:
      resources:
        limits:
          memory: 400M

EOF

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
echo "✅ NocoDB started at https://$DOMAIN"
