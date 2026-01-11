#!/bin/bash

# Mikrus Toolbox - FileBrowser
# Web-based File Manager (Google Drive alternative).
# Lightweight (Go), secure, and perfect for managing static sites.
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=40  # filebrowser/filebrowser:latest (bardzo lekki)
#
# Opcjonalne zmienne środowiskowe:
#   DOMAIN - domena dla File Manager (lub DOMAIN_ADMIN)
#   DOMAIN_PUBLIC - domena dla public static hosting

set -e

APP_NAME="filebrowser"
STACK_DIR="/opt/stacks/$APP_NAME"
DATA_DIR="/var/www/public"
PORT=${PORT:-8095}

echo "--- 📂 FileBrowser Setup ---"
echo "This will install a web file manager."
echo "Files will be stored in: $DATA_DIR"

# Domain for admin panel
DOMAIN_ADMIN="${DOMAIN_ADMIN:-$DOMAIN}"
if [ -n "$DOMAIN_ADMIN" ]; then
    echo "✅ Admin Panel: $DOMAIN_ADMIN"
else
    echo "⚠️  Brak domeny - używam localhost"
fi

# Optional public hosting domain
if [ -n "$DOMAIN_PUBLIC" ]; then
    echo "✅ Public Hosting: $DOMAIN_PUBLIC"
fi

# 1. Prepare Directories
sudo mkdir -p "$STACK_DIR"
sudo mkdir -p "$DATA_DIR"
sudo chown -R 1000:1000 "$DATA_DIR"
cd "$STACK_DIR"

# 2. Create DB file (FileBrowser needs it to exist)
touch filebrowser.db
sudo chown 1000:1000 filebrowser.db

# 3. Docker Compose
cat <<EOF | sudo tee docker-compose.yaml > /dev/null

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    restart: always
    ports:
      - "$PORT:80"
    volumes:
      - $DATA_DIR:/srv
      - ./filebrowser.db:/database.db
      - ./settings.json:/.filebrowser.json
    environment:
      - FB_DATABASE=/database.db
      - FB_ROOT=/srv
    deploy:
      resources:
        limits:
          memory: 128M

EOF

# 4. Start
sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 30 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ FileBrowser działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

# 5. Caddy Configuration
if [ -n "$DOMAIN_ADMIN" ] && [[ "$DOMAIN_ADMIN" != *"pending"* ]] && [[ "$DOMAIN_ADMIN" != *"cytrus"* ]]; then
    if command -v mikrus-expose &> /dev/null; then
        sudo mikrus-expose "$DOMAIN_ADMIN" "$PORT"

        # Public Hosting (Optional)
        if [ -n "$DOMAIN_PUBLIC" ]; then
            CADDYFILE="/etc/caddy/Caddyfile"
            if ! grep -q "$DOMAIN_PUBLIC" "$CADDYFILE"; then
                echo "🚀 Configuring Public Hosting at $DOMAIN_PUBLIC..."
                cat <<CONFIG | sudo tee -a "$CADDYFILE"

$DOMAIN_PUBLIC {
    root * $DATA_DIR
    file_server
    header Access-Control-Allow-Origin "*"
}
CONFIG
                sudo systemctl reload caddy
            fi
        fi
    fi
fi

echo ""
echo "✅ FileBrowser started!"
if [ -n "$DOMAIN_ADMIN" ]; then
    echo "🔗 Admin Panel: https://$DOMAIN_ADMIN"
else
    echo "🔗 Access via SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo "👤 Default Login: admin / admin"
echo "⚠️  CHANGE PASSWORD IMMEDIATELY!"
if [ -n "$DOMAIN_PUBLIC" ]; then
    echo ""
    echo "🌍 Public Hosting active: https://$DOMAIN_PUBLIC"
    echo "   Files uploaded to root folder will be visible here."
fi
