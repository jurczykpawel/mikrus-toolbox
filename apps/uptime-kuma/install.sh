#!/bin/bash

# Mikrus Toolbox - Uptime Kuma
# Self-hosted monitoring tool like "Uptime Robot".
# Very lightweight.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="uptime-kuma"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=3001

echo "--- 📈 Uptime Kuma Setup ---"
read -p "Domain (e.g., status.kamil.pl): " DOMAIN

# Setup Dir
sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Compose
cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    restart: always
    ports:
      - "127.0.0.1:$PORT:3001"
    volumes:
      - ./data:/app/data
    deploy:
      resources:
        limits:
          memory: 256M

EOF

# Start
sudo docker compose up -d

# Expose
if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
else
    echo "⚠️  Install Caddy first to expose domain automatically."
fi

echo "✅ Uptime Kuma started at https://$DOMAIN"
