#!/bin/bash

# Mikrus Toolbox - NocoDB
# Open Source Airtable alternative.
# Connects to your own database and turns it into a spreadsheet.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="nocodb"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=8080

echo "--- 📅 NocoDB Setup ---"
echo "We recommend using External PostgreSQL."
read -p "Database Host (or press Enter for internal SQLite - not recommended): " DB_HOST

if [ -n "$DB_HOST" ]; then
    read -p "Database Name: " DB_NAME
    read -p "Database User: " DB_USER
    read -s -p "Database Password: " DB_PASS
    echo ""
    # Connection string for PG
    DB_URL="pg://$DB_HOST:5432?u=$DB_USER&p=$DB_PASS&d=$DB_NAME"
else
    echo "Using internal SQLite (Warning: Higher RAM usage on host)"
    DB_URL="" # NocoDB defaults to SQLite if NC_DB is empty
fi

read -p "Domain (e.g., db.kamil.pl): " DOMAIN

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml
version: '3.8'

services:
  nocodb:
    image: nocodb/nocodb:latest
    restart: always
    ports:
      - "127.0.0.1:$PORT:8080"
    environment:
      - NC_DB=$DB_URL
      - NC_PUBLIC_URL=https://$DOMAIN
    volumes:
      - ./data:/usr/app/data
    deploy:
      resources:
        limits:
          memory: 400M

EOF

sudo docker compose up -d

if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ NocoDB started at https://$DOMAIN"
