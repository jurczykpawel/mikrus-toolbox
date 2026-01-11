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

services:
  stirling-pdf:
    image: froggle/s-pdf:latest
    restart: always
    ports:
      - "$PORT:8080"
    environment:
      - DOCKER_ENABLE_SECURITY=false
    deploy:
      resources:
        limits:
          memory: 512M # OCR operations can be heavy

EOF

sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 60 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Stirling-PDF działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo ""
echo "✅ Stirling-PDF started at https://$DOMAIN"
