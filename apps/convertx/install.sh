#!/bin/bash

# Mikrus Toolbox - ConvertX
# Self-hosted file converter. Images, documents, audio, video - 1000+ formats.
# https://github.com/C4illin/ConvertX
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=400  # ghcr.io/c4illin/convertx:latest

set -e

APP_NAME="convertx"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-3000}

echo "--- 🔄 ConvertX Setup ---"
echo "Uniwersalny konwerter plików w przeglądarce."
echo ""

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Domain
if [ -n "$DOMAIN" ]; then
    echo "✅ Domena: $DOMAIN"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
fi

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  convertx:
    image: ghcr.io/c4illin/convertx:latest
    restart: always
    ports:
      - "$PORT:3000"
    volumes:
      - ./data:/app/data
    deploy:
      resources:
        limits:
          memory: 256M
EOF

sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 30 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ ConvertX działa na porcie $PORT"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

echo ""
if [ -n "$DOMAIN" ]; then
    echo "🔗 Otwórz https://$DOMAIN"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo ""
echo "👤 Utwórz konto w przeglądarce przy pierwszym uruchomieniu."
