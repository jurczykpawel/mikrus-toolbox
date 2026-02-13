#!/bin/bash

# Mikrus Toolbox - Postiz
# AI-powered social media scheduling tool. Alternative to Buffer/Hootsuite.
# https://github.com/gitroomhq/postiz-app
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=1200  # ghcr.io/gitroomhq/postiz-app:latest
#
# ⚠️  UWAGA: Ta aplikacja zaleca minimum 2GB RAM (Mikrus 2.0+)!
#     Postiz (Next.js) + Redis = ~1-1.5GB RAM
#
# Wymagane zmienne środowiskowe (przekazywane przez deploy.sh):
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS - baza PostgreSQL
#   DOMAIN (opcjonalne)

set -e

APP_NAME="postiz"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-5000}

echo "--- 📱 Postiz Setup ---"
echo "AI-powered social media scheduler."
echo ""

# RAM check - soft warning (nie blokujemy, ale ostrzegamy)
TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")

if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 1800 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  UWAGA: Postiz zaleca minimum 2GB RAM!                   ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Twój serwer: ${TOTAL_RAM}MB RAM                             ║"
    echo "║  Zalecane:    2048MB RAM (Mikrus 2.0+)                       ║"
    echo "║                                                              ║"
    echo "║  Postiz + Redis = ~1-1.5GB RAM                               ║"
    echo "║  Na małym serwerze może być wolny.                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
fi

# Sprawdź dane bazy PostgreSQL
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "❌ Brak danych bazy PostgreSQL!"
    echo "   Wymagane: DB_HOST, DB_USER, DB_PASS, DB_NAME"
    echo ""
    echo "   Użyj deploy.sh - automatycznie skonfiguruje bazę:"
    echo "   ./local/deploy.sh postiz --ssh=hanna"
    exit 1
fi

DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-postiz}

echo "✅ Baza PostgreSQL: $DB_HOST:$DB_PORT/$DB_NAME (user: $DB_USER)"

# Buduj DATABASE_URL
DATABASE_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"

# Generuj sekrety
JWT_SECRET=$(openssl rand -hex 32)

# Domain
if [ -n "$DOMAIN" ]; then
    echo "✅ Domena: $DOMAIN"
    FRONTEND_URL="https://$DOMAIN"
    BACKEND_URL="https://$DOMAIN/api"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
    FRONTEND_URL="http://localhost:$PORT"
    BACKEND_URL="http://localhost:$PORT/api"
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    restart: always
    ports:
      - "$PORT:5000"
    environment:
      - DATABASE_URL=$DATABASE_URL
      - REDIS_URL=redis://postiz-redis:6379
      - JWT_SECRET=$JWT_SECRET
      - FRONTEND_URL=$FRONTEND_URL
      - NEXT_PUBLIC_BACKEND_URL=$BACKEND_URL
      - BACKEND_INTERNAL_URL=http://localhost:3000
      - UPLOAD_DIRECTORY=/uploads
      - NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads
    volumes:
      - ./uploads:/uploads
    depends_on:
      - postiz-redis
    deploy:
      resources:
        limits:
          memory: 1024M

  postiz-redis:
    image: redis:alpine
    restart: always
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - ./redis-data:/data
    deploy:
      resources:
        limits:
          memory: 128M
EOF

sudo docker compose up -d

# Health check - Next.js potrzebuje ~60-90s na start
echo "⏳ Czekam na uruchomienie Postiz (~60-90s, Next.js)..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 90 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    for i in $(seq 1 9); do
        sleep 10
        if curl -sf "http://localhost:$PORT" > /dev/null 2>&1; then
            echo "✅ Postiz działa (po $((i*10))s)"
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
if [ -n "$DOMAIN" ]; then
    echo "🔗 Otwórz https://$DOMAIN"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo ""
echo "📝 Następne kroki:"
echo "   1. Utwórz konto administratora w przeglądarce"
echo "   2. Podłącz konta social media (Twitter/X, LinkedIn, Instagram...)"
echo "   3. Zaplanuj pierwsze posty!"
