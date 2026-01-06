#!/bin/bash

# Mikrus Toolbox - Cap (Open Source Loom Alternative)
# Nagrywaj, edytuj i udostępniaj wideo w sekundy.
# https://github.com/CapSoftware/Cap
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="cap"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=3000

echo "--- 🎬 Cap Setup (Loom Alternative) ---"
echo "Cap pozwala nagrywać ekran i udostępniać wideo."
echo ""
echo "⚠️  UWAGA: Cap wymaga dużo zasobów!"
echo "   - MySQL (baza danych)"
echo "   - S3 Storage (na wideo)"
echo "   - Zalecane: Mikrus 4.0 (2GB RAM) lub wyższy"
echo ""

# 1. Wybór trybu bazy danych
echo "=== Konfiguracja MySQL ==="
echo "1) Zewnętrzna baza MySQL (zalecane dla Mikrus)"
echo "2) Lokalna baza MySQL (zje więcej RAM)"
read -p "Wybierz [1-2]: " DB_MODE

if [ "$DB_MODE" == "1" ]; then
    read -p "MySQL Host (np. srv15.mikr.us): " MYSQL_HOST
    read -p "MySQL Port (default 3306): " MYSQL_PORT
    MYSQL_PORT=${MYSQL_PORT:-3306}
    read -p "MySQL Database: " MYSQL_DB
    read -p "MySQL User: " MYSQL_USER
    read -s -p "MySQL Password: " MYSQL_PASS
    echo ""
    DATABASE_URL="mysql://${MYSQL_USER}:${MYSQL_PASS}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"
    USE_LOCAL_MYSQL="false"
else
    read -s -p "Ustaw hasło root dla MySQL: " MYSQL_ROOT_PASS
    echo ""
    MYSQL_DB="cap"
    DATABASE_URL="mysql://root:${MYSQL_ROOT_PASS}@cap-mysql:3306/${MYSQL_DB}"
    USE_LOCAL_MYSQL="true"
fi

# 2. Wybór trybu storage
echo ""
echo "=== Konfiguracja Storage (S3) ==="
echo "1) Zewnętrzny S3 (AWS, Cloudflare R2, Wasabi - zalecane)"
echo "2) Lokalny MinIO (zje dysk i RAM)"
read -p "Wybierz [1-2]: " S3_MODE

if [ "$S3_MODE" == "1" ]; then
    read -p "S3 Endpoint URL (np. https://xxx.r2.cloudflarestorage.com): " S3_ENDPOINT
    read -p "S3 Public URL (do odczytu wideo, może być CDN): " S3_PUBLIC_URL
    read -p "S3 Region (np. auto dla R2, us-east-1 dla AWS): " S3_REGION
    read -p "S3 Bucket Name: " S3_BUCKET
    read -p "S3 Access Key: " S3_ACCESS_KEY
    read -s -p "S3 Secret Key: " S3_SECRET_KEY
    echo ""
    USE_LOCAL_MINIO="false"
else
    S3_ACCESS_KEY="capS3root"
    S3_SECRET_KEY="capS3root"
    S3_BUCKET="cap-videos"
    S3_REGION="us-east-1"
    S3_ENDPOINT="http://cap-minio:9000"
    S3_PUBLIC_URL=""  # Will be set after domain input
    USE_LOCAL_MINIO="true"
fi

# 3. Domena i bezpieczeństwo
echo ""
echo "=== Konfiguracja Domeny ==="
read -p "Domena dla Cap (np. cap.mojafirma.pl): " DOMAIN

if [ "$USE_LOCAL_MINIO" == "true" ]; then
    S3_PUBLIC_URL="https://${DOMAIN}:3902"
    echo "⚠️  MinIO będzie dostępny na porcie 3902"
fi

# Generowanie secretów
echo ""
echo "Generuję klucze bezpieczeństwa..."
NEXTAUTH_SECRET=$(openssl rand -base64 32)
DATABASE_ENCRYPTION_KEY=$(openssl rand -base64 32)

# 4. Przygotowanie katalogu
sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# 5. Generowanie docker-compose.yaml
echo "--- Tworzę konfigurację Docker ---"

cat <<EOF | sudo tee docker-compose.yaml
version: "3.8"

services:
  cap-web:
    image: ghcr.io/capsoftware/cap-web:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:${PORT}:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - WEB_URL=https://${DOMAIN}
      - NEXTAUTH_URL=https://${DOMAIN}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - DATABASE_ENCRYPTION_KEY=${DATABASE_ENCRYPTION_KEY}
      - CAP_AWS_ACCESS_KEY=${S3_ACCESS_KEY}
      - CAP_AWS_SECRET_KEY=${S3_SECRET_KEY}
      - CAP_AWS_BUCKET=${S3_BUCKET}
      - CAP_AWS_REGION=${S3_REGION}
      - S3_PUBLIC_ENDPOINT=${S3_PUBLIC_URL}
      - S3_INTERNAL_ENDPOINT=${S3_ENDPOINT}
EOF

# Dodaj lokalne serwisy jeśli potrzebne
if [ "$USE_LOCAL_MYSQL" == "true" ]; then
cat <<EOF | sudo tee -a docker-compose.yaml
    depends_on:
      - cap-mysql

  cap-mysql:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}
      - MYSQL_DATABASE=${MYSQL_DB}
    volumes:
      - mysql-data:/var/lib/mysql
    deploy:
      resources:
        limits:
          memory: 512M
EOF
fi

if [ "$USE_LOCAL_MINIO" == "true" ]; then
cat <<EOF | sudo tee -a docker-compose.yaml

  cap-minio:
    image: bitnami/minio:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:3902:9000"
      - "127.0.0.1:3903:9001"
    environment:
      - MINIO_ROOT_USER=${S3_ACCESS_KEY}
      - MINIO_ROOT_PASSWORD=${S3_SECRET_KEY}
      - MINIO_DEFAULT_BUCKETS=${S3_BUCKET}
    volumes:
      - minio-data:/bitnami/minio/data
    deploy:
      resources:
        limits:
          memory: 256M
EOF
fi

# Volumes section
cat <<EOF | sudo tee -a docker-compose.yaml

volumes:
EOF

if [ "$USE_LOCAL_MYSQL" == "true" ]; then
    echo "  mysql-data:" | sudo tee -a docker-compose.yaml
fi

if [ "$USE_LOCAL_MINIO" == "true" ]; then
    echo "  minio-data:" | sudo tee -a docker-compose.yaml
fi

# Memory limit dla cap-web
sudo sed -i '/cap-web:/,/environment:/{ /image:/a\    deploy:\n      resources:\n        limits:\n          memory: 512M' docker-compose.yaml 2>/dev/null || true

echo ""
echo "--- Uruchamiam Cap ---"
sudo docker compose up -d

echo ""
echo "--- Konfiguruję HTTPS via Caddy ---"
if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
else
    echo "⚠️  'mikrus-expose' nie znaleziono. Zainstaluj Caddy: system/caddy-install.sh"
    echo "   Lub skonfiguruj reverse proxy ręcznie na port $PORT"
fi

if [ "$USE_LOCAL_MINIO" == "true" ]; then
    echo ""
    echo "⚠️  MinIO wymaga osobnej konfiguracji proxy dla portu 3902"
fi

echo ""
echo "============================================"
echo "✅ Cap zainstalowany!"
echo "🔗 Otwórz https://$DOMAIN aby rozpocząć"
echo ""
echo "📝 Zapisz te dane w bezpiecznym miejscu:"
echo "   NEXTAUTH_SECRET: $NEXTAUTH_SECRET"
echo "   DATABASE_ENCRYPTION_KEY: $DATABASE_ENCRYPTION_KEY"
echo "============================================"
