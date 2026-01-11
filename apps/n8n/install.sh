#!/bin/bash

# Mikrus Toolbox - n8n (External Database Optimized)
# Installs n8n optimized for low-RAM environment, connecting to external PostgreSQL.
# Perfect for Mikrus + Shared DB or "Cegła" DB.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="n8n"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=5678

echo "--- 🧠 n8n Setup (Smart Mode) ---"
echo "This setup assumes you are using an External PostgreSQL (e.g., Mikrus Shared DB or Dedicated)."
echo "This saves RAM and CPU on your VPS."
echo ""

# 1. Database Credentials (from environment or prompt)
if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
    echo "✅ Używam danych bazy z konfiguracji:"
    echo "   Host: $DB_HOST | User: $DB_USER | DB: $DB_NAME"
    DB_PORT=${DB_PORT:-5432}
else
    echo "📝 Podaj dane bazy PostgreSQL:"
    read -p "Database Host (e.g., psql01.mikr.us): " DB_HOST
    read -p "Database Port (default 5432): " DB_PORT
    DB_PORT=${DB_PORT:-5432}
    read -p "Database Name: " DB_NAME
    read -p "Database User: " DB_USER
    read -s -p "Database Password: " DB_PASS
    echo ""
fi
# Domain (from environment or prompt)
if [ -n "$DOMAIN" ]; then
    echo "✅ Używam domeny z konfiguracji: $DOMAIN"
else
    echo ""
    read -p "Domain for n8n (e.g., n8n.example.com): " DOMAIN
fi
read -p "Webhook URL [https://$DOMAIN/]: " WEBHOOK_URL
WEBHOOK_URL=${WEBHOOK_URL:-https://$DOMAIN/}

# 2. Prepare Directory
sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Utwórz katalog data z odpowiednimi uprawnieniami (n8n działa jako UID 1000)
sudo mkdir -p "$STACK_DIR/data"
sudo chown -R 1000:1000 "$STACK_DIR/data"

# 3. Create docker-compose.yaml
# Features:
# - External DB connection
# - Memory limits (critical for Mikrus)
# - Timezone set to Europe/Warsaw
# - Execution logs pruning (keep DB small)

cat <<EOF | sudo tee docker-compose.yaml

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "$PORT:5678"
    environment:
      - N8N_HOST=$DOMAIN
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=$WEBHOOK_URL
      - GENERIC_TIMEZONE=Europe/Warsaw
      - TZ=Europe/Warsaw
      
      # Database Configuration
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=$DB_HOST
      - DB_POSTGRESDB_PORT=$DB_PORT
      - DB_POSTGRESDB_DATABASE=$DB_NAME
      - DB_POSTGRESDB_SCHEMA=${DB_SCHEMA:-public}
      - DB_POSTGRESDB_USER=$DB_USER
      - DB_POSTGRESDB_PASSWORD=$DB_PASS
      
      # Security
      - N8N_BASIC_AUTH_ACTIVE=true
      # (User will set up user/pass on first launch via UI)
      
      # Pruning (Keep database slim)
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168 # 7 Days
      - EXECUTIONS_DATA_PRUNE_MAX_COUNT=10000
      
      # Memory Optimization
      # Disable diagnostics to save ram
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=true
    volumes:
      - ./data:/home/node/.n8n
    deploy:
      resources:
        limits:
          memory: 600M  # Prevent n8n from killing the server

EOF

echo "--- 4. Starting n8n ---"
sudo docker compose up -d

# Health check - sprawdź czy kontener działa i app odpowiada
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 60 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Kontener działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

# Caddy/HTTPS - tylko dla prawdziwych domen (nie placeholder Cytrus)
if [[ "$DOMAIN" != *"pending"* ]] && [[ "$DOMAIN" != *"cytrus"* ]]; then
    echo "--- 5. Configuring HTTPS via Caddy ---"
    if command -v mikrus-expose &> /dev/null; then
        sudo mikrus-expose "$DOMAIN" "$PORT"
    else
        echo "⚠️  'mikrus-expose' not found. Install Caddy first via system/caddy-install.sh"
        echo "   Or configure your reverse proxy manually."
    fi
fi

echo ""
echo "✅ n8n Installed & Started!"
echo "🔗 Open https://$DOMAIN to finish setup."
