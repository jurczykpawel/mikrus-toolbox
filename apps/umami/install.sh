#!/bin/bash

# Mikrus Toolbox - Umami Analytics
# Simple, privacy-friendly alternative to Google Analytics.
#
# ⚠️  WYMAGANIA: PostgreSQL z rozszerzeniem pgcrypto!
#     Współdzielona baza Mikrusa NIE działa (brak uprawnień do tworzenia rozszerzeń).
#     Użyj: płatny PostgreSQL z https://mikr.us/panel/?a=cloud
#
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="umami"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=3000

echo "--- 📊 Umami Analytics Setup ---"
echo "Requires PostgreSQL Database."

# Database credentials (from environment or prompt)
if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
    echo "✅ Używam danych bazy z konfiguracji:"
    echo "   Host: $DB_HOST | User: $DB_USER | DB: $DB_NAME"
    DB_PORT=${DB_PORT:-5432}
else
    echo "📝 Podaj dane bazy PostgreSQL:"
    read -p "Database Host: " DB_HOST
    read -p "Database Name: " DB_NAME
    read -p "Database User: " DB_USER
    read -s -p "Database Password: " DB_PASS
    DB_PORT=5432
    echo ""
fi

# ⚠️ Sprawdź czy to współdzielona baza Mikrusa (nie obsługuje pgcrypto)
# Blokujemy tylko psql*.mikr.us (darmowa współdzielona), NIE mws*.mikr.us (płatna dedykowana)
if [[ "$DB_HOST" == psql*.mikr.us ]]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ BŁĄD: Umami NIE działa ze współdzieloną bazą Mikrusa!      ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Umami wymaga rozszerzenia 'pgcrypto', które nie jest          ║"
    echo "║  dostępne w darmowej bazie Mikrusa.                            ║"
    echo "║                                                                ║"
    echo "║  Rozwiązanie: Kup dedykowany PostgreSQL (od 5 PLN/mies.)       ║"
    echo "║  https://mikr.us/panel/?a=cloud                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# Schema (opcjonalnie - dla izolacji w istniejącej bazie)
echo ""
echo "💡 Możesz użyć osobnego schematu (np. 'umami') żeby odizolować dane."
echo "   Zostaw puste dla domyślnego schematu 'public'."
read -p "Schema [public]: " DB_SCHEMA
DB_SCHEMA="${DB_SCHEMA:-public}"

# Buduj DATABASE_URL
if [ "$DB_SCHEMA" = "public" ]; then
    DATABASE_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"
else
    DATABASE_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME?schema=$DB_SCHEMA"
    echo ""
    echo "⚠️  Upewnij się że schemat '$DB_SCHEMA' istnieje w bazie!"
    echo "   CREATE SCHEMA $DB_SCHEMA;"
fi

# Generate random hash salt
HASH_SALT=$(openssl rand -hex 32)

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  umami:
    image: ghcr.io/umami-software/umami:postgresql-latest
    restart: always
    ports:
      - "$PORT:3000"
    environment:
      - DATABASE_URL=$DATABASE_URL
      - DATABASE_TYPE=postgresql
      - APP_SECRET=$HASH_SALT
    deploy:
      resources:
        limits:
          memory: 256M
EOF

sudo docker compose up -d

# Health check - sprawdź czy kontener działa i app odpowiada
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true

if type wait_for_healthy &>/dev/null; then
    if ! wait_for_healthy "$APP_NAME" "$PORT" 60; then
        echo "❌ Instalacja nie powiodła się!"
        exit 1
    fi
else
    # Fallback - proste sprawdzenie
    echo "Sprawdzam czy kontener wystartował..."
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Kontener działa"
    else
        echo "❌ Kontener nie wystartował!"
        sudo docker compose logs --tail 20
        exit 1
    fi
fi

echo ""
echo "✅ Umami zainstalowane pomyślnie"
echo "Default user: admin / umami"
echo "👉 CHANGE PASSWORD IMMEDIATELY!"
