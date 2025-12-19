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
read -p "Domain (e.g., notify.kamil.pl): " DOMAIN

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Basic config with cache enabled
cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  ntfy:
    image: binwiederhier/ntfy
    restart: always
    command: serve
    environment:
      - NTFY_BASE_URL=https://$DOMAIN
      - NTFY_CACHE_FILE=/var/cache/ntfy/cache.db
      - NTFY_AUTH_FILE=/var/cache/ntfy/user.db
      - NTFY_AUTH_DEFAULT_ACCESS=deny-all
      - NTFY_BEHIND_PROXY=true
    volumes:
      - ./cache:/var/cache/ntfy
    ports:
      - "127.0.0.1:$PORT:80"
    deploy:
      resources:
        limits:
          memory: 128M

EOF

sudo docker compose up -d

# Create default admin user? 
# ntfy requires CLI access to create users.
# We will instruct user.

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ ntfy started at https://$DOMAIN"
echo "⚠️  Important: You set 'deny-all' by default."
echo "   Create your user/admin now by running:"
echo "   docker exec -it ntfy_ntfy_1 ntfy user add --role=admin your_user"
