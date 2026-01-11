#!/bin/bash

# Mikrus Toolbox - Typebot
# Conversational Form Builder (Open Source Typeform Alternative).
# Requires External PostgreSQL.
# Author: Paweł (Lazy Engineer)
#
# Wymagane zmienne środowiskowe (przekazywane przez deploy.sh):
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS
#   DOMAIN (opcjonalne - używane do generowania builder.$DOMAIN i $DOMAIN)
#
# Opcjonalne zmienne (jeśli chcesz własne domeny):
#   DOMAIN_BUILDER - domena dla Builder UI
#   DOMAIN_VIEWER - domena dla Viewer

set -e

APP_NAME="typebot"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT_BUILDER=8081
PORT_VIEWER=8082

echo "--- 🤖 Typebot Setup ---"
echo "Requires PostgreSQL Database."

# Validate database credentials
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ]; then
    echo "❌ Błąd: Brak danych bazy danych!"
    echo "   Wymagane zmienne: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS"
    exit 1
fi

echo "✅ Dane bazy danych:"
echo "   Host: $DB_HOST | User: $DB_USER | DB: $DB_NAME"

DB_PORT=${DB_PORT:-5432}

# Domain configuration
# Typebot requires 2 domains: Builder and Viewer
if [ -n "$DOMAIN_BUILDER" ] && [ -n "$DOMAIN_VIEWER" ]; then
    # Explicit domains provided
    echo "✅ Builder: $DOMAIN_BUILDER"
    echo "✅ Viewer:  $DOMAIN_VIEWER"
elif [ -n "$DOMAIN" ]; then
    # Auto-generate from base domain
    DOMAIN_BUILDER="builder.${DOMAIN#builder.}"  # Remove 'builder.' prefix if present
    DOMAIN_VIEWER="${DOMAIN#builder.}"           # Remove 'builder.' prefix if present
    echo "✅ Builder: $DOMAIN_BUILDER (auto)"
    echo "✅ Viewer:  $DOMAIN_VIEWER (auto)"
else
    echo "⚠️  Brak domen - używam localhost"
    DOMAIN_BUILDER=""
    DOMAIN_VIEWER=""
fi

# Generate secret
ENCRYPTION_SECRET=$(openssl rand -hex 32)

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Set URLs based on domain availability
if [ -n "$DOMAIN_BUILDER" ]; then
    NEXTAUTH_URL="https://$DOMAIN_BUILDER"
    VIEWER_URL="https://$DOMAIN_VIEWER"
    ADMIN_EMAIL="admin@$DOMAIN_BUILDER"
else
    NEXTAUTH_URL="http://localhost:$PORT_BUILDER"
    VIEWER_URL="http://localhost:$PORT_VIEWER"
    ADMIN_EMAIL="admin@localhost"
fi

cat <<EOF | sudo tee docker-compose.yaml > /dev/null

services:
  typebot-builder:
    image: baptistearno/typebot-builder:latest
    restart: always
    ports:
      - "$PORT_BUILDER:3000"
    environment:
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME
      - NEXTAUTH_URL=$NEXTAUTH_URL
      - NEXT_PUBLIC_VIEWER_URL=$VIEWER_URL
      - ENCRYPTION_SECRET=$ENCRYPTION_SECRET
      - ADMIN_EMAIL=$ADMIN_EMAIL
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
      - NEXTAUTH_URL=$NEXTAUTH_URL
      - NEXT_PUBLIC_VIEWER_URL=$VIEWER_URL
      - ENCRYPTION_SECRET=$ENCRYPTION_SECRET
    deploy:
      resources:
        limits:
          memory: 300M

EOF

sudo docker compose up -d

# Health check (check both ports)
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

# Caddy/HTTPS - only for real domains
if [ -n "$DOMAIN_BUILDER" ] && [[ "$DOMAIN_BUILDER" != *"pending"* ]] && [[ "$DOMAIN_BUILDER" != *"cytrus"* ]]; then
    if command -v mikrus-expose &> /dev/null; then
        sudo mikrus-expose "$DOMAIN_BUILDER" "$PORT_BUILDER"
        sudo mikrus-expose "$DOMAIN_VIEWER" "$PORT_VIEWER"
    fi
fi

echo ""
echo "✅ Typebot started!"
if [ -n "$DOMAIN_BUILDER" ]; then
    echo "   Builder: https://$DOMAIN_BUILDER"
    echo "   Viewer:  https://$DOMAIN_VIEWER"
else
    echo "   Builder: ssh -L $PORT_BUILDER:localhost:$PORT_BUILDER <server>"
    echo "   Viewer:  ssh -L $PORT_VIEWER:localhost:$PORT_VIEWER <server>"
fi
echo "👉 Note: S3 storage for file uploads is NOT configured in this lite setup."
