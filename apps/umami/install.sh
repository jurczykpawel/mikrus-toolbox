#!/bin/bash

# Mikrus Toolbox - Umami Analytics
# Simple, privacy-friendly alternative to Google Analytics.
# Requires External PostgreSQL (recommended) or local DB.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="umami"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=3000

echo "--- 📊 Umami Analytics Setup ---"
echo "Requires PostgreSQL Database."

read -p "Database Host: " DB_HOST
read -p "Database Name: " DB_NAME
read -p "Database User: " DB_USER
read -s -p "Database Password: " DB_PASS
echo ""
read -p "Domain (e.g., stats.kamil.pl): " DOMAIN

# Generate random hash salt
HASH_SALT=$(openssl rand -hex 32)

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  umami:
    image: ghcr.io/umami-software/umami:postgresql-latest
    restart: always
    ports:
      - "127.0.0.1:$PORT:3000"
    environment:
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:5432/$DB_NAME
      - DATABASE_TYPE=postgresql
      - APP_SECRET=$HASH_SALT
    deploy:
      resources:
        limits:
          memory: 256M

EOF

sudo docker compose up -d

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ Umami started at https://$DOMAIN"
echo "Default user: admin / umami"
echo "👉 CHANGE PASSWORD IMMEDIATELY!"
