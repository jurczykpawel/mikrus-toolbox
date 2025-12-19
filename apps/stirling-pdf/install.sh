#!/bin/bash

# Mikrus Toolbox - Stirling-PDF
# Your local, privacy-friendly PDF Swiss Army Knife.
# Merge, Split, Convert, OCR - all in your browser.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="stirling-pdf"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=8087

echo "--- 📄 Stirling-PDF Setup ---"
read -p "Domain (e.g., pdf.kamil.pl): " DOMAIN

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  stirling-pdf:
    image: froggle/s-pdf:latest
    restart: always
    ports:
      - "127.0.0.1:$PORT:8080"
    environment:
      - DOCKER_ENABLE_SECURITY=false
    deploy:
      resources:
        limits:
          memory: 512M # OCR operations can be heavy

EOF

sudo docker compose up -d

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ Stirling-PDF started at https://$DOMAIN"
