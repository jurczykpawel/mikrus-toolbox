#!/bin/bash

# Mikrus Toolbox - Vaultwarden
# Lightweight Bitwarden server written in Rust.
# Secure password management for your business.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="vaultwarden"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=8088

echo "--- 🔐 Vaultwarden Setup ---"
echo "NOTE: Once installed, create your account immediately."
echo "Then, restart the container with SIGNUPS_ALLOWED=false to secure it."
echo ""
read -p "Domain (e.g., vault.kamil.pl): " DOMAIN
read -p "Admin Token (for admin panel, optional but recommended): " ADMIN_TOKEN

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  vaultwarden:
    image: vaultwarden/server:latest
    restart: always
    ports:
      - "127.0.0.1:$PORT:80"
    environment:
      - DOMAIN=https://$DOMAIN
      - SIGNUPS_ALLOWED=true 
      - ADMIN_TOKEN=$ADMIN_TOKEN
      # Websockets enabled for sync
      - WEBSOCKET_ENABLED=true
    volumes:
      - ./data:/data
    deploy:
      resources:
        limits:
          memory: 128M

EOF

sudo docker compose up -d

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ Vaultwarden started at https://$DOMAIN"
echo "⚠️  ACTION REQUIRED:"
echo "1. Create your account NOW."
echo "2. Edit docker-compose.yaml and set SIGNUPS_ALLOWED=false"
echo "3. Run 'docker compose up -d' to apply."
