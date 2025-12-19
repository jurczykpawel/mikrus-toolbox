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
version: '3.8'

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

echo "✅ Redis started on port $PORT"
echo "Password: (hidden)"
