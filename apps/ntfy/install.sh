#!/bin/bash

# Mikrus Toolbox - ntfy.sh
# Self-hosted push notifications server.
# Send alerts from n8n directly to your phone.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="ntfy"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=8085

echo "--- 🔔 ntfy Setup ---"

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Basic config with cache enabled
cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  ntfy:
    image: binwiederhier/ntfy
    restart: always
    command: serve
    environment:
      - NTFY_BASE_URL=https://notify.example.com
      - NTFY_CACHE_FILE=/var/cache/ntfy/cache.db
      - NTFY_AUTH_FILE=/var/cache/ntfy/user.db
      - NTFY_AUTH_DEFAULT_ACCESS=deny-all
      - NTFY_BEHIND_PROXY=true
    volumes:
      - ./cache:/var/cache/ntfy
    ports:
      - "$PORT:80"
    deploy:
      resources:
        limits:
          memory: 128M
EOF

sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 30 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ ntfy działa na porcie $PORT"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi
echo ""
echo "⚠️  Po skonfigurowaniu domeny zaktualizuj NTFY_BASE_URL:"
echo "   ssh $SSH_ALIAS \"sed -i 's|notify.example.com|TWOJA_DOMENA|' $STACK_DIR/docker-compose.yaml && cd $STACK_DIR && docker compose up -d\""
echo ""
echo "👤 Utwórz użytkownika do logowania w ntfy:"
echo "   ssh $SSH_ALIAS 'docker exec -it ntfy-ntfy-1 ntfy user add --role=admin TWOJ_USER'"
echo "   (to nowy user wewnętrzny ntfy, nie systemowy)"
