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

# 1. Gather Database Credentials
read -p "Database Host (e.g., srv15.mikr.us): " DB_HOST
read -p "Database Port (default 5432): " DB_PORT
DB_PORT=${DB_PORT:-5432}
read -p "Database Name: " DB_NAME
read -p "Database User: " DB_USER
read -s -p "Database Password: " DB_PASS
echo ""
echo ""
read -p "Domain for n8n (e.g., n8n.kamil.pl): " DOMAIN
read -p "Webhook URL (https://$DOMAIN/): " WEBHOOK_URL
WEBHOOK_URL=${WEBHOOK_URL:-https://$DOMAIN/}

# 2. Prepare Directory
sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# 3. Create docker-compose.yaml
# Features:
# - External DB connection
# - Memory limits (critical for Mikrus)
# - Timezone set to Europe/Warsaw
# - Execution logs pruning (keep DB small)

cat <<EOF | sudo tee docker-compose.yaml
version: "3.8"

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "127.0.0.1:$PORT:5678"
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
      
    deploy:
      resources:
        limits:
          memory: 600M  # Prevent n8n from killing the server

EOF

echo "--- 4. Starting n8n ---"
sudo docker compose up -d

echo "--- 5. Configuring HTTPS via Caddy ---"
if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
else
    echo "⚠️  'mikrus-expose' not found. Install Caddy first via system/caddy-install.sh"
    echo "   Or configure your reverse proxy manually."
fi

echo ""
echo "✅ n8n Installed & Started!"
echo "🔗 Open https://$DOMAIN to finish setup."
