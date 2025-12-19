#!/bin/bash

# Mikrus Toolbox - Typebot
# Conversational Form Builder (Open Source Typeform Alternative).
# Requires External PostgreSQL.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="typebot"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT_BUILDER=8081
PORT_VIEWER=8082

echo "--- 🤖 Typebot Setup ---"
echo "Requires PostgreSQL Database."

read -p "Database Host: " DB_HOST
read -p "Database Name: " DB_NAME
read -p "Database User: " DB_USER
read -s -p "Database Password: " DB_PASS
echo ""
echo "--- Domains ---"
read -p "Builder Domain (e.g., builder.bot.kamil.pl): " DOMAIN_BUILDER
read -p "Viewer Domain (e.g., bot.kamil.pl): " DOMAIN_VIEWER

# Generate secret
ENCRYPTION_SECRET=$(openssl rand -hex 32)

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  typebot-builder:
    image: baptistearno/typebot-builder:latest
    restart: always
    ports:
      - "127.0.0.1:$PORT_BUILDER:3000"
    environment:
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:5432/$DB_NAME
      - NEXTAUTH_URL=https://$DOMAIN_BUILDER
      - NEXT_PUBLIC_VIEWER_URL=https://$DOMAIN_VIEWER
      - ENCRYPTION_SECRET=$ENCRYPTION_SECRET
      - ADMIN_EMAIL=admin@$DOMAIN_BUILDER # First user is admin
    depends_on:
      - typebot-viewer
    deploy:
      resources:
        limits:
          memory: 300M

  typebot-viewer:
    image: baptistearno/typebot-viewer:latest
    restart: always
    ports:
      - "127.0.0.1:$PORT_VIEWER:3000"
    environment:
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:5432/$DB_NAME
      - NEXTAUTH_URL=https://$DOMAIN_BUILDER
      - NEXT_PUBLIC_VIEWER_URL=https://$DOMAIN_VIEWER
      - ENCRYPTION_SECRET=$ENCRYPTION_SECRET
    deploy:
      resources:
        limits:
          memory: 300M

EOF

sudo docker compose up -d

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN_BUILDER" "$PORT_BUILDER"
    sudo mikrus-expose "$DOMAIN_VIEWER" "$PORT_VIEWER"
fi

echo "✅ Typebot started!"
echo "   Builder: https://$DOMAIN_BUILDER"
echo "   Viewer:  https://$DOMAIN_VIEWER"
echo "👉 Note: S3 storage for file uploads is NOT configured in this lite setup."
