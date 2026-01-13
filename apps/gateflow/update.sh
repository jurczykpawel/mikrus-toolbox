#!/bin/bash

# Mikrus Toolbox - GateFlow Update
# Aktualizuje GateFlow do najnowszej wersji
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   Na serwerze: ./apps/gateflow/update.sh
#   Lokalnie przez SSH: ssh hanna 'bash -s' < apps/gateflow/update.sh
#
# Zmienne środowiskowe:
#   DATABASE_URL - URL do bazy Supabase (dla migracji)
#   SKIP_MIGRATIONS - ustaw na 1 aby pominąć migracje

set -e

INSTALL_DIR="/root/gateflow"
GITHUB_REPO="pavvel11/gateflow"
MIGRATIONS_PATH="supabase/migrations"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}🔄 GateFlow Update${NC}"
echo ""

# =============================================================================
# 1. SPRAWDŹ CZY GATEFLOW JEST ZAINSTALOWANY
# =============================================================================

if [ ! -d "$INSTALL_DIR/admin-panel" ]; then
    echo -e "${RED}❌ GateFlow nie jest zainstalowany${NC}"
    echo "   Użyj deploy.sh do pierwszej instalacji."
    exit 1
fi

ENV_FILE="$INSTALL_DIR/admin-panel/.env.local"
STANDALONE_DIR="$INSTALL_DIR/admin-panel/.next/standalone/admin-panel"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Brak pliku .env.local${NC}"
    exit 1
fi

echo "✅ GateFlow znaleziony w $INSTALL_DIR"

# Pobierz aktualną wersję (jeśli dostępna)
CURRENT_VERSION="nieznana"
if [ -f "$INSTALL_DIR/admin-panel/version.txt" ]; then
    CURRENT_VERSION=$(cat "$INSTALL_DIR/admin-panel/version.txt")
fi
echo "   Aktualna wersja: $CURRENT_VERSION"

# =============================================================================
# 2. POBIERZ NOWĄ WERSJĘ
# =============================================================================

echo ""
echo "📥 Pobieram najnowszą wersję..."

# Backup starej konfiguracji
cp "$ENV_FILE" "$INSTALL_DIR/.env.local.backup"
echo "   Backup .env.local utworzony"

# Pobierz do tymczasowego folderu
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

RELEASE_URL="https://github.com/$GITHUB_REPO/releases/latest/download/gateflow-build.tar.gz"
if ! curl -L "$RELEASE_URL" | tar -xz; then
    echo -e "${RED}❌ Nie udało się pobrać nowej wersji${NC}"
    exit 1
fi

if [ ! -d ".next/standalone" ]; then
    echo -e "${RED}❌ Nieprawidłowa struktura archiwum${NC}"
    exit 1
fi

# Sprawdź nową wersję
NEW_VERSION="nieznana"
if [ -f "version.txt" ]; then
    NEW_VERSION=$(cat version.txt)
fi
echo "   Nowa wersja: $NEW_VERSION"

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ] && [ "$CURRENT_VERSION" != "nieznana" ]; then
    echo -e "${YELLOW}⚠️  Masz już najnowszą wersję ($CURRENT_VERSION)${NC}"
    read -p "Kontynuować mimo to? [t/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[TtYy]$ ]]; then
        echo "Anulowano."
        exit 0
    fi
fi

# =============================================================================
# 3. ZATRZYMAJ APLIKACJĘ
# =============================================================================

echo ""
echo "⏹️  Zatrzymuję GateFlow..."

export PATH="$HOME/.bun/bin:$PATH"
pm2 stop gateflow-admin 2>/dev/null || true

# =============================================================================
# 4. ZAMIEŃ PLIKI
# =============================================================================

echo ""
echo "📦 Aktualizuję pliki..."

# Usuń stare pliki (zachowaj .env.local backup)
rm -rf "$INSTALL_DIR/admin-panel/.next"
rm -rf "$INSTALL_DIR/admin-panel/public"

# Skopiuj nowe
cp -r "$TEMP_DIR/.next" "$INSTALL_DIR/admin-panel/"
cp -r "$TEMP_DIR/public" "$INSTALL_DIR/admin-panel/" 2>/dev/null || true
cp "$TEMP_DIR/version.txt" "$INSTALL_DIR/admin-panel/" 2>/dev/null || true

# Przywróć .env.local
cp "$INSTALL_DIR/.env.local.backup" "$ENV_FILE"

# Skopiuj do standalone
STANDALONE_DIR="$INSTALL_DIR/admin-panel/.next/standalone/admin-panel"
if [ -d "$STANDALONE_DIR" ]; then
    cp "$ENV_FILE" "$STANDALONE_DIR/.env.local"
    cp -r "$INSTALL_DIR/admin-panel/.next/static" "$STANDALONE_DIR/.next/" 2>/dev/null || true
    cp -r "$INSTALL_DIR/admin-panel/public" "$STANDALONE_DIR/" 2>/dev/null || true
fi

echo -e "${GREEN}✅ Pliki zaktualizowane${NC}"

# =============================================================================
# 5. MIGRACJE (opcjonalne)
# =============================================================================

if [ "$SKIP_MIGRATIONS" != "1" ]; then
    echo ""
    echo "🗄️  Sprawdzam migracje..."

    # Sprawdź czy mamy DATABASE_URL
    if [ -z "$DATABASE_URL" ]; then
        # Spróbuj odczytać z .env.local (nie znajdziemy, bo to Supabase URL a nie DATABASE_URL)
        echo -e "${YELLOW}⚠️  DATABASE_URL nie ustawiony${NC}"
        echo ""
        echo "Aby uruchomić migracje, potrzebujesz Database URL z Supabase:"
        echo "   1. Otwórz: https://supabase.com/dashboard"
        echo "   2. Wybierz projekt → Settings → Database"
        echo "   3. Sekcja 'Connection string' → URI"
        echo ""
        read -p "Wklej Database URL (lub Enter aby pominąć migracje): " DATABASE_URL
    fi

    if [ -n "$DATABASE_URL" ]; then
        echo ""
        echo "📥 Pobieram pliki migracji..."

        MIGRATIONS_TEMP=$(mktemp -d)

        # Pobierz listę migracji
        MIGRATIONS_LIST=$(curl -sL "https://api.github.com/repos/$GITHUB_REPO/contents/$MIGRATIONS_PATH" \
            -H "Authorization: token ${GITHUB_TOKEN:-}" 2>/dev/null | grep -o '"name": "[^"]*\.sql"' | cut -d'"' -f4 | sort)

        if [ -z "$MIGRATIONS_LIST" ]; then
            echo -e "${YELLOW}⚠️  Nie udało się pobrać listy migracji - pomijam${NC}"
        else
            # Pobierz każdy plik
            for migration in $MIGRATIONS_LIST; do
                curl -sL "https://raw.githubusercontent.com/$GITHUB_REPO/main/$MIGRATIONS_PATH/$migration" \
                    -H "Authorization: token ${GITHUB_TOKEN:-}" \
                    -o "$MIGRATIONS_TEMP/$migration"
            done

            # Sprawdź które są już wykonane
            MIGRATIONS_TABLE_EXISTS=$(docker run --rm postgres:15-alpine psql "$DATABASE_URL" -t -c \
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'schema_migrations');" 2>/dev/null | tr -d ' ')

            if [ "$MIGRATIONS_TABLE_EXISTS" = "t" ]; then
                APPLIED_MIGRATIONS=$(docker run --rm postgres:15-alpine psql "$DATABASE_URL" -t -c \
                    "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' ' | grep -v '^$')
            else
                APPLIED_MIGRATIONS=""
                # Utwórz tabelę
                docker run --rm postgres:15-alpine psql "$DATABASE_URL" -c \
                    "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT NOW());" 2>/dev/null
            fi

            # Wykonaj brakujące
            PENDING=0
            for migration in $MIGRATIONS_LIST; do
                VERSION=$(echo "$migration" | cut -d'_' -f1)
                if ! echo "$APPLIED_MIGRATIONS" | grep -q "^$VERSION$"; then
                    PENDING=$((PENDING + 1))
                    echo "   Wykonuję: $migration"

                    if docker run --rm -v "$MIGRATIONS_TEMP/$migration:/migration.sql" postgres:15-alpine \
                        psql "$DATABASE_URL" -f /migration.sql 2>/dev/null; then
                        docker run --rm postgres:15-alpine psql "$DATABASE_URL" -c \
                            "INSERT INTO schema_migrations (version) VALUES ('$VERSION');" 2>/dev/null
                        echo -e "   ${GREEN}✅ $migration${NC}"
                    else
                        echo -e "   ${RED}❌ Błąd w $migration${NC}"
                    fi
                fi
            done

            if [ $PENDING -eq 0 ]; then
                echo -e "${GREEN}✅ Wszystkie migracje już zastosowane${NC}"
            fi

            rm -rf "$MIGRATIONS_TEMP"
        fi
    else
        echo "⏭️  Pominięto migracje"
    fi
fi

# =============================================================================
# 6. URUCHOM APLIKACJĘ
# =============================================================================

echo ""
echo "🚀 Uruchamiam GateFlow..."

cd "$STANDALONE_DIR"

# Załaduj zmienne i uruchom
set -a
source .env.local
set +a
export PORT="${PORT:-3333}"
export HOSTNAME="${HOSTNAME:-0.0.0.0}"

pm2 delete gateflow-admin 2>/dev/null || true
pm2 start "node server.js" --name gateflow-admin
pm2 save

# Poczekaj i sprawdź
sleep 3

if pm2 list | grep -q "gateflow-admin.*online"; then
    echo -e "${GREEN}✅ GateFlow działa!${NC}"
else
    echo -e "${RED}❌ Problem z uruchomieniem. Logi:${NC}"
    pm2 logs gateflow-admin --lines 20
    exit 1
fi

# =============================================================================
# 7. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ GateFlow zaktualizowany!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "   Poprzednia wersja: $CURRENT_VERSION"
echo "   Nowa wersja: $NEW_VERSION"
echo ""
echo "📋 Przydatne komendy:"
echo "   pm2 logs gateflow-admin - logi"
echo "   pm2 restart gateflow-admin - restart"
echo ""
