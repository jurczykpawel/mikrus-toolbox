#!/bin/bash

# Mikrus Toolbox - Subtitle Burner
# Twórz, styluj i wypalaj animowane napisy na wideo.
# Edytor wizualny, 8 szablonów, transkrypcja AI, server-side rendering (FFmpeg).
# https://github.com/jurczykpawel/subtitle-burner
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=900  # Next.js + Bun + FFmpeg + Nginx + PostgreSQL + Redis + MinIO
#
# ⚠️  UWAGA: Ta aplikacja wymaga minimum 2GB RAM (Mikrus 3.0+)!
#     6 kontenerów: web, worker (FFmpeg), nginx, postgres, redis, minio.
#     Na Mikrus 2.1 (1GB RAM) nie uruchomi się poprawnie.
#
# Stack: Next.js (Bun) + BullMQ Worker (FFmpeg) + PostgreSQL 16 + Redis 7 + MinIO + Nginx

set -e

APP_NAME="subtitle-burner"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-3000}
REPO_URL="https://github.com/jurczykpawel/subtitle-burner.git"

echo "--- 🎬 Subtitle Burner Setup ---"
echo "Wypalaj animowane napisy na wideo."
echo ""

# Port binding: Cytrus wymaga 0.0.0.0, Cloudflare/local → 127.0.0.1
if [ "${DOMAIN_TYPE:-}" = "cytrus" ]; then
    BIND_ADDR=""
else
    BIND_ADDR="127.0.0.1:"
fi

# Sprawdź dostępny RAM - WYMAGANE minimum 2GB!
TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")

if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 1800 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ BŁĄD: Za mało RAM dla Subtitle Burner!                   ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Twój serwer: ${TOTAL_RAM}MB RAM                             ║"
    echo "║  Wymagane:    2048MB RAM (Mikrus 3.0+)                       ║"
    echo "║                                                              ║"
    echo "║  6 kontenerów: web, worker (FFmpeg), postgres, redis, minio. ║"
    echo "║  Na Mikrus 2.1 nie uruchomi się poprawnie!                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# Domain
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "✅ Domena: $DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "✅ Domena: automatyczna (Cytrus)"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Klonuj lub aktualizuj repozytorium
if [ -d "$STACK_DIR/repo/.git" ]; then
    echo "📦 Aktualizuję repozytorium..."
    cd "$STACK_DIR/repo"
    sudo git pull --quiet
    cd "$STACK_DIR"
else
    echo "📦 Klonuję repozytorium..."
    sudo git clone --depth 1 "$REPO_URL" "$STACK_DIR/repo"
fi

# Generuj sekrety
AUTH_SECRET=$(openssl rand -base64 32)
PG_PASS=$(openssl rand -hex 16)
MINIO_ACCESS=$(openssl rand -hex 12)
MINIO_SECRET=$(openssl rand -hex 24)

# URL aplikacji
APP_URL="http://localhost:$PORT"
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    APP_URL="https://$DOMAIN"
fi

# Generuj .env
cat <<EOF | sudo tee .env > /dev/null
# App
AUTH_SECRET=$AUTH_SECRET
NEXT_PUBLIC_APP_URL=$APP_URL
NODE_ENV=production

# PostgreSQL
POSTGRES_USER=subtitle_burner
POSTGRES_PASSWORD=$PG_PASS
POSTGRES_DB=subtitle_burner
POSTGRES_PORT=5432
DATABASE_URL=postgresql://subtitle_burner:${PG_PASS}@postgres:5432/subtitle_burner

# Redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379

# MinIO (object storage)
MINIO_ENDPOINT=minio
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ACCESS_KEY=$MINIO_ACCESS
MINIO_SECRET_KEY=$MINIO_SECRET
MINIO_BUCKET=subtitle-burner
MINIO_USE_SSL=false

# Email (opcjonalnie - do magic links)
# SMTP_HOST=smtp.resend.com
# SMTP_PORT=587
# SMTP_USER=resend
# SMTP_PASS=re_xxxxx
# EMAIL_FROM=noreply@yourdomain.com
EOF

sudo chmod 600 .env
echo "✅ Konfiguracja wygenerowana"

# Nginx config (z repo)
sudo cp "$STACK_DIR/repo/docker/nginx.conf" "$STACK_DIR/nginx.conf" 2>/dev/null || true

# Generuj docker-compose.yaml
cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "${BIND_ADDR}${PORT}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      web:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 64M

  web:
    build:
      context: ./repo
      dockerfile: docker/Dockerfile
    env_file: .env
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M

  worker:
    build:
      context: ./repo
      dockerfile: docker/Dockerfile.worker
    env_file: .env
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512M

  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: subtitle_burner
      POSTGRES_PASSWORD: $PG_PASS
      POSTGRES_DB: subtitle_burner
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U subtitle_burner"]
      interval: 5s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 256M

  redis:
    image: redis:7-alpine
    restart: always
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 64M

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    restart: always
    environment:
      MINIO_ROOT_USER: $MINIO_ACCESS
      MINIO_ROOT_PASSWORD: $MINIO_SECRET
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 256M

volumes:
  postgres_data:
  redis_data:
  minio_data:
EOF

# Buduj i uruchamiaj
echo "🔨 Buduję obrazy Docker (to może potrwać kilka minut)..."
sudo docker compose build --quiet 2>/dev/null || sudo docker compose build
sudo docker compose up -d

# Czekaj na PostgreSQL
echo "⏳ Czekam na PostgreSQL..."
for i in $(seq 1 12); do
    if sudo docker compose exec -T postgres pg_isready -U subtitle_burner > /dev/null 2>&1; then
        break
    fi
    sleep 5
done

# Migracje bazy danych
echo "📦 Uruchamiam migracje bazy danych..."
sudo docker compose exec -T web ./node_modules/.bin/prisma migrate deploy --schema=/app/packages/database/prisma/schema.prisma || {
    echo "⚠️  Migracje nie powiodły się (pierwszy start może wymagać retry)."
    echo "   Spróbuj ręcznie: cd $STACK_DIR && sudo docker compose exec web ./node_modules/.bin/prisma migrate deploy --schema=/app/packages/database/prisma/schema.prisma"
}

# Health check
echo "⏳ Czekam na uruchomienie (~30-60s)..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 90 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    for i in $(seq 1 9); do
        sleep 10
        if curl -sf "http://localhost:$PORT/" > /dev/null 2>&1; then
            echo "✅ Subtitle Burner działa (po $((i*10))s)"
            break
        fi
        echo "   ... $((i*10))s"
        if [ "$i" -eq 9 ]; then
            echo "❌ Kontener nie wystartował w 90s!"
            sudo docker compose logs --tail 30
            exit 1
        fi
    done
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Subtitle Burner zainstalowany!"
echo "════════════════════════════════════════════════════════════════"
echo ""
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "🔗 Aplikacja:  https://$DOMAIN"
    echo "🔗 API (docs): https://$DOMAIN/api/health"
elif [ "$DOMAIN" = "-" ]; then
    echo "🔗 Domena zostanie skonfigurowana automatycznie po instalacji"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
    echo "   http://localhost:$PORT"
fi
echo ""
echo "🔑 Sekrety zapisane w: $STACK_DIR/.env"
echo ""
echo "📋 Następne kroki:"
echo "   1. Otwórz aplikację i zarejestruj konto"
echo "   2. (Opcjonalnie) Skonfiguruj SMTP w .env → magic link auth"
echo "   3. Wgraj wideo i przetestuj wypalanie napisów"
echo ""
echo "📋 Funkcje:"
echo "   - 8 szablonów napisów (Classic, Cinematic, Bold Box...)"
echo "   - 6 animacji (word-highlight, karaoke, bounce...)"
echo "   - Transkrypcja AI (Whisper w przeglądarce)"
echo "   - Server-side rendering przez FFmpeg (worker)"
echo "   - REST API (21 endpointów)"
