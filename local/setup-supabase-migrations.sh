#!/bin/bash

# Mikrus Toolbox - Supabase Migrations
# Wykonuje migracje bazy danych dla GateFlow
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/setup-supabase-migrations.sh [ssh_alias]
#
# Przykłady:
#   ./local/setup-supabase-migrations.sh hanna    # Migracje na serwerze
#   ./local/setup-supabase-migrations.sh          # Migracje lokalne

set -e

SSH_ALIAS="${1:-}"
GITHUB_REPO="pavvel11/gateflow"
MIGRATIONS_PATH="supabase/migrations"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}🗄️  Supabase Migrations${NC}"
echo ""

# =============================================================================
# 1. POBIERZ DATABASE URL
# =============================================================================

# Sprawdź czy mamy DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo "Potrzebuję Database URL z Supabase."
    echo ""
    echo "Gdzie go znaleźć:"
    echo "   1. Otwórz: https://supabase.com/dashboard"
    echo "   2. Wybierz projekt → Settings → Database"
    echo "   3. Sekcja 'Connection string' → URI"
    echo "   4. Skopiuj (zaczyna się od postgresql://)"
    echo ""

    # Otwórz przeglądarkę
    read -p "Naciśnij Enter aby otworzyć Supabase..." _
    if command -v open &>/dev/null; then
        open "https://supabase.com/dashboard"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://supabase.com/dashboard"
    fi

    echo ""
    read -p "Wklej Database URL (postgresql://...): " DATABASE_URL

    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}❌ Database URL jest wymagany${NC}"
        exit 1
    fi
fi

# Walidacja URL
if [[ ! "$DATABASE_URL" =~ ^postgresql:// ]]; then
    echo -e "${RED}❌ Nieprawidłowy format URL (powinien zaczynać się od postgresql://)${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Database URL otrzymany${NC}"

# =============================================================================
# 2. POBIERZ MIGRACJE
# =============================================================================

echo ""
echo "📥 Pobieram pliki migracji..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Pobierz listę migracji
MIGRATIONS_LIST=$(curl -sL "https://api.github.com/repos/$GITHUB_REPO/contents/$MIGRATIONS_PATH" \
    -H "Authorization: token ${GITHUB_TOKEN:-}" 2>/dev/null | grep -o '"name": "[^"]*\.sql"' | cut -d'"' -f4 | sort)

if [ -z "$MIGRATIONS_LIST" ]; then
    echo -e "${RED}❌ Nie udało się pobrać listy migracji${NC}"
    exit 1
fi

echo "   Znaleziono migracje:"
for migration in $MIGRATIONS_LIST; do
    echo "   - $migration"
done

# Pobierz każdy plik
for migration in $MIGRATIONS_LIST; do
    echo "   Pobieram: $migration"
    curl -sL "https://raw.githubusercontent.com/$GITHUB_REPO/main/$MIGRATIONS_PATH/$migration" \
        -H "Authorization: token ${GITHUB_TOKEN:-}" \
        -o "$TEMP_DIR/$migration"
done

echo -e "${GREEN}✅ Migracje pobrane${NC}"

# =============================================================================
# 3. SPRAWDŹ KTÓRE MIGRACJE SĄ POTRZEBNE
# =============================================================================

echo ""
echo "🔍 Sprawdzam status migracji..."

# Funkcja do wykonania SQL
run_sql() {
    local SQL="$1"
    if [ -n "$SSH_ALIAS" ]; then
        # Na serwerze przez Docker (psql czyta hasło z DATABASE_URL)
        ssh "$SSH_ALIAS" "docker run --rm postgres:15-alpine psql '$DATABASE_URL' -t -c \"$SQL\"" 2>/dev/null
    else
        # Lokalnie - spróbuj psql lub Docker
        if command -v psql &>/dev/null; then
            psql "$DATABASE_URL" -t -c "$SQL" 2>/dev/null
        elif command -v docker &>/dev/null; then
            docker run --rm postgres:15-alpine psql "$DATABASE_URL" -t -c "$SQL" 2>/dev/null
        else
            echo ""
            return 1
        fi
    fi
}

# Sprawdź czy tabela migracji istnieje
MIGRATIONS_TABLE_EXISTS=$(run_sql "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'schema_migrations');" | tr -d ' ')

if [ "$MIGRATIONS_TABLE_EXISTS" = "t" ]; then
    echo "   Tabela migracji istnieje"
    APPLIED_MIGRATIONS=$(run_sql "SELECT version FROM schema_migrations ORDER BY version;" | tr -d ' ' | grep -v '^$')
else
    echo "   Tabela migracji nie istnieje (fresh install)"
    APPLIED_MIGRATIONS=""
fi

# Określ które migracje trzeba wykonać
PENDING_MIGRATIONS=""
for migration in $MIGRATIONS_LIST; do
    VERSION=$(echo "$migration" | cut -d'_' -f1)
    if ! echo "$APPLIED_MIGRATIONS" | grep -q "^$VERSION$"; then
        PENDING_MIGRATIONS="$PENDING_MIGRATIONS $migration"
    fi
done

PENDING_MIGRATIONS=$(echo "$PENDING_MIGRATIONS" | xargs)

if [ -z "$PENDING_MIGRATIONS" ]; then
    echo -e "${GREEN}✅ Wszystkie migracje już zastosowane${NC}"
    exit 0
fi

echo ""
echo "📋 Migracje do wykonania:"
for migration in $PENDING_MIGRATIONS; do
    echo -e "   ${YELLOW}→ $migration${NC}"
done

# =============================================================================
# 4. WYKONAJ MIGRACJE
# =============================================================================

echo ""
read -p "Wykonać migracje? [T/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Anulowano."
    exit 0
fi

echo ""
echo "🚀 Wykonuję migracje..."

# Utwórz tabelę migracji jeśli nie istnieje
if [ "$MIGRATIONS_TABLE_EXISTS" != "t" ]; then
    echo "   Tworzę tabelę schema_migrations..."
    run_sql "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT NOW());"
fi

# Wykonaj każdą migrację
for migration in $PENDING_MIGRATIONS; do
    VERSION=$(echo "$migration" | cut -d'_' -f1)
    echo "   Wykonuję: $migration"

    SQL_CONTENT=$(cat "$TEMP_DIR/$migration")

    if [ -n "$SSH_ALIAS" ]; then
        # Skopiuj plik na serwer i wykonaj
        scp -q "$TEMP_DIR/$migration" "$SSH_ALIAS:/tmp/migration_$$.sql"
        if ssh "$SSH_ALIAS" "docker run --rm -v /tmp/migration_$$.sql:/migration.sql postgres:15-alpine psql '$DATABASE_URL' -f /migration.sql" 2>/dev/null; then
            # Zapisz że migracja została wykonana
            ssh "$SSH_ALIAS" "docker run --rm postgres:15-alpine psql '$DATABASE_URL' -c \"INSERT INTO schema_migrations (version) VALUES ('$VERSION');\"" 2>/dev/null
            ssh "$SSH_ALIAS" "rm -f /tmp/migration_$$.sql"
            echo -e "   ${GREEN}✅ $migration${NC}"
        else
            echo -e "   ${RED}❌ Błąd w $migration${NC}"
            ssh "$SSH_ALIAS" "rm -f /tmp/migration_$$.sql"
            exit 1
        fi
    else
        # Lokalnie
        if command -v psql &>/dev/null; then
            if psql "$DATABASE_URL" -f "$TEMP_DIR/$migration" 2>/dev/null; then
                psql "$DATABASE_URL" -c "INSERT INTO schema_migrations (version) VALUES ('$VERSION');" 2>/dev/null
                echo -e "   ${GREEN}✅ $migration${NC}"
            else
                echo -e "   ${RED}❌ Błąd w $migration${NC}"
                exit 1
            fi
        elif command -v docker &>/dev/null; then
            if docker run --rm -v "$TEMP_DIR/$migration:/migration.sql" postgres:15-alpine psql "$DATABASE_URL" -f /migration.sql 2>/dev/null; then
                docker run --rm postgres:15-alpine psql "$DATABASE_URL" -c "INSERT INTO schema_migrations (version) VALUES ('$VERSION');" 2>/dev/null
                echo -e "   ${GREEN}✅ $migration${NC}"
            else
                echo -e "   ${RED}❌ Błąd w $migration${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ Brak psql ani Docker${NC}"
            exit 1
        fi
    fi
done

echo ""
echo -e "${GREEN}🎉 Migracje wykonane pomyślnie!${NC}"
