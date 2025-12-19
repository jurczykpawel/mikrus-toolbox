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
version: '3.8'

services:
  linkstack:
    image: linkstackorg/linkstack
    restart: always
    ports:
      - "127.0.0.1:$PORT:80"
    volumes:
      - ./data:/htdocs
    deploy:
      resources:
        limits:
          memory: 256M

EOF

sudo docker compose up -d

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ LinkStack started at https://$DOMAIN"
echo "Open the URL to finalize installation wizard."
