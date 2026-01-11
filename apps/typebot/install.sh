#!/bin/bash

# Mikrus Toolbox - Typebot
# Conversational Form Builder (Open Source Typeform Alternative).
# Requires External PostgreSQL.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="typebot"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT_BUILDER=8081
PORT_VIEWER=8082

echo "--- 🤖 Typebot Setup ---"
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
    DB_PORT=5432
    echo ""
fi
echo ""
echo "--- Domains ---"
echo "Typebot wymaga dwóch domen: Builder (do tworzenia) i Viewer (do wyświetlania)"
# Domain hints from environment
if [ -n "$DOMAIN" ]; then
    echo "💡 Sugestia bazująca na konfiguracji: builder.$DOMAIN i $DOMAIN"
fi
read -p "Builder Domain (e.g., builder.bot.kamil.pl): " DOMAIN_BUILDER
read -p "Viewer Domain (e.g., bot.kamil.pl): " DOMAIN_VIEWER

# Generate secret
ENCRYPTION_SECRET=$(openssl rand -hex 32)

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml

services:
  typebot-builder:
    image: baptistearno/typebot-builder:latest
    restart: always
    ports:
      - "$PORT_BUILDER:3000"
    environment:
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME
      - NEXTAUTH_URL=https://$DOMAIN_BUILDER
      - NEXT_PUBLIC_VIEWER_URL=https://$DOMAIN_VIEWER
      - ENCRYPTION_SECRET=$ENCRYPTION_SECRET
      - ADMIN_EMAIL=admin@$DOMAIN_BUILDER # First user is admin
    depends_on:
      - typebot-viewer
    deploy:
      resources:
        limits:
          memory: 300M

  typebot-viewer:
    image: baptistearno/typebot-viewer:latest
    restart: always
    ports:
      - "$PORT_VIEWER:3000"
    environment:
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME
      - NEXTAUTH_URL=https://$DOMAIN_BUILDER
      - NEXT_PUBLIC_VIEWER_URL=https://$DOMAIN_VIEWER
      - ENCRYPTION_SECRET=$ENCRYPTION_SECRET
    deploy:
      resources:
        limits:
          memory: 300M

EOF

sudo docker compose up -d

# Health check (sprawdź oba porty)
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT_BUILDER" 60 || { echo "❌ Builder nie wystartował!"; exit 1; }
    echo "Sprawdzam Viewer..."
    curl -s -o /dev/null --max-time 5 "http://localhost:$PORT_VIEWER" && echo "✅ Viewer odpowiada" || echo "⚠️  Viewer może potrzebować więcej czasu"
else
    sleep 8
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Typebot kontenery działają"
    else
        echo "❌ Kontenery nie wystartowały!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN_BUILDER" "$PORT_BUILDER"
    sudo mikrus-expose "$DOMAIN_VIEWER" "$PORT_VIEWER"
fi

echo ""
echo "✅ Typebot started!"
echo "   Builder: https://$DOMAIN_BUILDER"
echo "   Viewer:  https://$DOMAIN_VIEWER"
echo "👉 Note: S3 storage for file uploads is NOT configured in this lite setup."
