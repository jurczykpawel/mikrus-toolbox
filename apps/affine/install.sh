#!/bin/bash

# Mikrus Toolbox - AFFiNE
# Open-source baza wiedzy — alternatywa dla Notion + Miro.
# Dokumenty, tablice, bazy danych w jednym miejscu.
# https://affine.pro
# Author: Pawel (Lazy Engineer)
#
# IMAGE_SIZE_MB=750  # affine (~273MB) + pgvector/pgvector:pg16 (~350MB) + redis:alpine (~40MB)
#
# WYMAGANIA: PostgreSQL 16 z rozszerzeniem pgvector!
#     Współdzielona baza Mikrusa NIE działa (PostgreSQL 12 bez pgvector).
#     Minimum 2GB RAM (zalecane 4GB).
#
# Stack: 4 kontenery
#   - affine (aplikacja)
#   - affine_migration (jednorazowa migracja DB)
#   - postgres (pgvector/pgvector:pg16)
#   - redis (cache)
#
# Wymagane zmienne środowiskowe (przekazywane przez deploy.sh):
#   DB_HOST, DB_USER, DB_PASS, DB_NAME (opcjonalne — jeśli external DB)
#   DOMAIN (opcjonalne)

set -e

APP_NAME="affine"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-3010}

echo "--- 📝 AFFiNE Setup ---"
echo "Baza wiedzy — Notion + Miro alternative."
echo ""

# Port binding: Cytrus wymaga 0.0.0.0, Cloudflare/local → 127.0.0.1
if [ "${DOMAIN_TYPE:-}" = "cytrus" ]; then
    BIND_ADDR=""
else
    BIND_ADDR="127.0.0.1:"
fi

# =============================================================================
# RAM CHECK — AFFiNE wymaga minimum 2GB
# =============================================================================
FREE_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "0")

if [ "$FREE_RAM" -gt 0 ] && [ "$FREE_RAM" -lt 2000 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  UWAGA: AFFiNE zaleca minimum 2GB wolnego RAM!           ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Wolny RAM: ${FREE_RAM}MB                                    ║"
    echo "║  Zalecane:  2000MB+ (Mikrus 3.5+)                           ║"
    echo "║                                                              ║"
    echo "║  AFFiNE + PostgreSQL + Redis = ~1.5GB RAM                    ║"
    echo "║  Na serwerze z <2GB mogą być problemy ze stabilnością.       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
fi

# =============================================================================
# BAZA DANYCH — BUNDLED (pgvector) vs EXTERNAL
# =============================================================================
if [ -n "${DB_HOST:-}" ] && [ -n "${DB_USER:-}" ] && [ -n "${DB_PASS:-}" ] && [ -n "${DB_NAME:-}" ]; then
    # External DB — przekazana przez deploy.sh (--db=custom)
    USE_BUNDLED_PG=false
    DB_PORT=${DB_PORT:-5432}
    echo "✅ Baza PostgreSQL: external ($DB_HOST:$DB_PORT/$DB_NAME)"
    echo ""
    echo "⚠️  Upewnij się, że external DB to PostgreSQL 16+ z rozszerzeniem pgvector!"
    echo "   Współdzielona baza Mikrusa (PG 12) NIE zadziała."
else
    # Bundled DB — pgvector/pgvector:pg16 w compose
    USE_BUNDLED_PG=true
    DB_USER="affine"
    DB_PASS=$(openssl rand -hex 16)
    DB_NAME="affine"
    DB_HOST="postgres"
    DB_PORT=5432
    echo "✅ Baza PostgreSQL: bundled (pgvector/pgvector:pg16)"
fi

# =============================================================================
# DOMAIN / URL
# =============================================================================
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "✅ Domena: $DOMAIN"
    SERVER_URL="https://$DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "✅ Domena: automatyczna (Cytrus) — URL zostanie zaktualizowany"
    SERVER_URL="http://localhost:$PORT"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
    SERVER_URL="http://localhost:$PORT"
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# =============================================================================
# DOCKER COMPOSE — 4 KONTENERY
# =============================================================================
cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  affine:
    image: ghcr.io/toeverything/affine:stable
    container_name: affine_server
    restart: unless-stopped
    ports:
      - "${BIND_ADDR}${PORT}:3010"
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
      affine_migration:
        condition: service_completed_successfully
    volumes:
      - ./storage:/root/.affine/storage
      - ./config:/root/.affine/config
    environment:
      - REDIS_SERVER_HOST=redis
      - DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
      - AFFINE_SERVER_EXTERNAL_URL=${SERVER_URL}
      - AFFINE_INDEXER_ENABLED=false
    deploy:
      resources:
        limits:
          memory: 1024M

  affine_migration:
    image: ghcr.io/toeverything/affine:stable
    container_name: affine_migration_job
    volumes:
      - ./storage:/root/.affine/storage
      - ./config:/root/.affine/config
    command: ['sh', '-c', 'node ./scripts/self-host-predeploy.js']
    environment:
      - REDIS_SERVER_HOST=redis
      - DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
      - AFFINE_INDEXER_ENABLED=false
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  redis:
    image: redis:alpine
    container_name: affine_redis
    restart: unless-stopped
    healthcheck:
      test: ['CMD', 'redis-cli', '--raw', 'incr', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 128M

  postgres:
    image: pgvector/pgvector:pg16
    container_name: affine_postgres
    restart: unless-stopped
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    healthcheck:
      test: ['CMD', 'pg_isready', '-U', '${DB_USER}', '-d', '${DB_NAME}']
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 256M

volumes:
  db-data:
EOF

echo ""
echo "✅ Docker Compose wygenerowany (4 kontenery)"
echo "   Uruchamiam stack..."
echo ""

sudo docker compose up -d

# Health check — migracja + start zajmuje więcej czasu
echo "⏳ Czekam na uruchomienie AFFiNE (~60-120s, migracja bazy + start)..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 120 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    for i in $(seq 1 12); do
        sleep 10
        if curl -sf "http://localhost:$PORT" > /dev/null 2>&1; then
            echo "✅ AFFiNE działa (po $((i*10))s)"
            break
        fi
        echo "   ... $((i*10))s"
        if [ "$i" -eq 12 ]; then
            echo "❌ Kontener nie wystartował w 120s!"
            sudo docker compose logs --tail 30
            exit 1
        fi
    done
fi

# Caddy/HTTPS — tylko dla prawdziwych domen
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ] && [[ "$DOMAIN" != *"pending"* ]] && [[ "$DOMAIN" != *"cytrus"* ]]; then
    if command -v mikrus-expose &> /dev/null; then
        sudo mikrus-expose "$DOMAIN" "$PORT"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ AFFiNE zainstalowane!"
echo "════════════════════════════════════════════════════════════════"
echo ""
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "🔗 Otwórz https://$DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "🔗 Domena zostanie skonfigurowana automatycznie po instalacji"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo ""
echo "📝 Następne kroki:"
echo "   1. Utwórz konto administratora w przeglądarce"
echo "   2. Pierwszy zarejestrowany użytkownik staje się adminem"
echo ""
echo "⚠️  Wymagania RAM:"
echo "   AFFiNE + PostgreSQL + Redis = ~1.5GB RAM"
echo "   Zalecany serwer: Mikrus 3.5+ (4GB RAM)"
