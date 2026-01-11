#!/bin/bash

# Mikrus Toolbox - Redis
# In-memory data store. Useful for n8n caching or queues.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="redis"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=6379

echo "--- ⚡ Redis Setup ---"
read -s -p "Set Redis Password: " REDIS_PASS
echo ""

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml

services:
  redis:
    image: redis:alpine
    restart: always
    command: redis-server --requirepass $REDIS_PASS --save 60 1 --loglevel warning
    ports:
      - "127.0.0.1:$PORT:6379"
    volumes:
      - ./data:/data
    deploy:
      resources:
        limits:
          memory: 128M

EOF

sudo docker compose up -d

# Health check (redis nie ma HTTP, sprawdzamy tylko kontener)
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type check_container_running &>/dev/null; then
    check_container_running "$APP_NAME" || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 3
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Redis działa na porcie $PORT"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi
echo "Password: (ukryte)"
