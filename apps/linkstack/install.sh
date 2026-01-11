#!/bin/bash

# Mikrus Toolbox - LinkStack
# Self-hosted "Link in Bio" page.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="linkstack"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=8090

echo "--- 🔗 LinkStack Setup ---"
read -p "Domain (e.g., links.kamil.pl): " DOMAIN

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml

services:
  linkstack:
    image: linkstackorg/linkstack
    restart: always
    ports:
      - "$PORT:80"
    volumes:
      - ./data:/htdocs
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

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo ""
echo "✅ LinkStack started at https://$DOMAIN"
echo "Open the URL to finalize installation wizard."
