#!/bin/bash

# Mikrus Toolbox - FileBrowser
# Web-based File Manager (Google Drive alternative).
# Lightweight (Go), secure, and perfect for managing static sites.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="filebrowser"
STACK_DIR="/opt/stacks/$APP_NAME"
# We separate data storage to easily share it with Caddy or other apps
DATA_DIR="/var/www/public" 
PORT=8095

echo "--- 📂 FileBrowser Setup ---"
echo "This will install a web file manager."
echo "Files will be stored in: $DATA_DIR"

read -p "Domain for File Manager (e.g., files.kamil.pl): " DOMAIN_ADMIN
read -p "Domain for Public Hosting (e.g., static.kamil.pl) [Optional, press Enter to skip]: " DOMAIN_PUBLIC

# 1. Prepare Directories
sudo mkdir -p "$STACK_DIR"
sudo mkdir -p "$DATA_DIR"
# Set permissions so container can write (User 1000 is default inside)
sudo chown -R 1000:1000 "$DATA_DIR"
cd "$STACK_DIR"

# 2. Create DB file (FileBrowser needs it to exist)
touch filebrowser.db
sudo chown 1000:1000 filebrowser.db

# 3. Docker Compose
cat <<EOF | sudo tee docker-compose.yaml

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
if command -v mikrus-expose &> /dev/null; then
    # Admin Panel
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

echo "✅ FileBrowser started at https://$DOMAIN_ADMIN"
echo "👤 Default Login: admin / admin"
echo "⚠️  CHANGE PASSWORD IMMEDIATELY!"
echo ""
if [ -n "$DOMAIN_PUBLIC" ]; then
    echo "🌍 Public Hosting active: https://$DOMAIN_PUBLIC"
    echo "   Files uploaded to root folder will be visible here."
fi
