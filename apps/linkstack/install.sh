#!/bin/bash

# Mikrus Toolbox - LinkStack
# Self-hosted "Link in Bio" page.
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=550  # linkstackorg/linkstack:latest
#
# Opcjonalne zmienne środowiskowe:
#   DOMAIN - domena dla LinkStack

set -e

APP_NAME="linkstack"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8090}

echo "--- 🔗 LinkStack Setup ---"

# Domain
if [ -n "$DOMAIN" ]; then
    echo "✅ Domena: $DOMAIN"
else
    echo "⚠️  Brak domeny - używam localhost"
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# LinkStack wymaga katalogu data z odpowiednimi uprawnieniami
sudo mkdir -p data
sudo chown -R 100:101 data  # Apache user (uid=100, gid=101) w kontenerze

cat <<EOF | sudo tee docker-compose.yaml > /dev/null

services:
  linkstack:
    image: linkstackorg/linkstack
    restart: always
    ports:
      - "$PORT:80"
    volumes:
      - ./data:/htdocs
    environment:
      - SERVER_ADMIN=admin@localhost
      - TZ=Europe/Warsaw
    deploy:
      resources:
        limits:
          memory: 256M

EOF

sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 45 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ LinkStack działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

# Caddy/HTTPS - only for real domains
if [ -n "$DOMAIN" ] && [[ "$DOMAIN" != *"pending"* ]] && [[ "$DOMAIN" != *"cytrus"* ]]; then
    if command -v mikrus-expose &> /dev/null; then
        sudo mikrus-expose "$DOMAIN" "$PORT"
    fi
fi

echo ""
echo "✅ LinkStack started!"
if [ -n "$DOMAIN" ]; then
    echo "🔗 Open https://$DOMAIN"
else
    echo "🔗 Access via SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo "Open the URL to finalize installation wizard."
