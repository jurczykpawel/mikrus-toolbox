#!/bin/bash

# Mikrus Toolbox - Database Setup Helper
# Używany przez skrypty instalacyjne do konfiguracji bazy danych.
# Author: Paweł (Lazy Engineer)
#
# NOWY FLOW z CLI:
#   1. parse_args() + load_defaults()  - z cli-parser.sh
#   2. ask_database()    - sprawdza flagi, pyta tylko gdy brak
#   3. fetch_database()  - pobiera dane z API (jeśli shared)
#
# Flagi CLI:
#   --db-source=shared|custom
#   --db-host=HOST --db-port=PORT --db-name=NAME
#   --db-schema=SCHEMA --db-user=USER --db-pass=PASS
#
# Po wywołaniu dostępne zmienne:
#   $DB_HOST, $DB_PORT, $DB_NAME, $DB_SCHEMA, $DB_USER, $DB_PASS, $DB_SOURCE

# Załaduj cli-parser jeśli nie załadowany
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! type ask_if_empty &>/dev/null; then
    source "$SCRIPT_DIR/cli-parser.sh"
fi

# Kolory (jeśli nie zdefiniowane przez cli-parser)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
NC="${NC:-\033[0m}"

# Zmienne eksportowane (nie resetuj jeśli już ustawione)
export DB_HOST="${DB_HOST:-}"
export DB_PORT="${DB_PORT:-}"
export DB_NAME="${DB_NAME:-}"
export DB_SCHEMA="${DB_SCHEMA:-}"
export DB_USER="${DB_USER:-}"
export DB_PASS="${DB_PASS:-}"
export DB_SOURCE="${DB_SOURCE:-}"

# Aplikacje wymagające pgcrypto (nie działają ze współdzieloną bazą Mikrusa)
# n8n od wersji 1.121+ wymaga gen_random_uuid() które potrzebuje pgcrypto lub PostgreSQL 13+
REQUIRES_PGCRYPTO="umami n8n"

# =============================================================================
# FAZA 1: Zbieranie informacji (respektuje flagi CLI)
# =============================================================================

ask_database() {
    local DB_TYPE="${1:-postgres}"
    local APP_NAME="${2:-}"

    # Sprawdź czy aplikacja wymaga pgcrypto
    local SHARED_BLOCKED=false
    if [[ " $REQUIRES_PGCRYPTO " == *" $APP_NAME "* ]]; then
        SHARED_BLOCKED=true
    fi

    # Jeśli DB_SOURCE już ustawione z CLI
    if [ -n "$DB_SOURCE" ]; then
        # Walidacja: shared zablokowane dla niektórych apps
        if [ "$DB_SOURCE" = "shared" ] && [ "$SHARED_BLOCKED" = true ]; then
            echo -e "${RED}Błąd: $APP_NAME wymaga dedykowanej bazy (--db-source=custom)${NC}" >&2
            echo "   Współdzielona baza Mikrus nie obsługuje pgcrypto." >&2
            echo "   Wykup dedykowany PostgreSQL: https://mikr.us/panel/?a=cloud" >&2
            return 1
        fi

        # Walidacja: custom wymaga pełnych danych
        if [ "$DB_SOURCE" = "custom" ]; then
            if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
                if [ "$YES_MODE" = true ]; then
                    echo -e "${RED}Błąd: --db-source=custom wymaga --db-host, --db-name, --db-user, --db-pass${NC}" >&2
                    return 1
                fi
                # Tryb interaktywny - dopytaj o brakujące
                ask_custom_db "$DB_TYPE"
                return $?
            fi
        fi

        echo -e "${GREEN}✅ Baza danych: $DB_SOURCE${NC}"
        return 0
    fi

    # Tryb --yes bez --db-source = błąd
    if [ "$YES_MODE" = true ]; then
        echo -e "${RED}Błąd: --db-source jest wymagane w trybie --yes${NC}" >&2
        return 1
    fi

    # Tryb interaktywny
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🗄️  Konfiguracja bazy danych ($DB_TYPE)"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Gdzie ma być baza danych?"
    echo ""

    if [ "$SHARED_BLOCKED" = true ]; then
        echo "  1) 🚫 Współdzielona baza Mikrus (NIEDOSTĘPNA)"
        echo "     $APP_NAME wymaga rozszerzenia pgcrypto"
        echo ""
    else
        echo "  1) 🆓 Współdzielona baza Mikrus (darmowa)"
        echo "     Automatycznie pobierze dane z API Mikrusa"
        echo "     ➜ Wystarczająca dla większości zastosowań"
        echo ""
    fi

    echo "  2) 💰 Własna/wykupiona baza"
    echo "     Podasz własne dane połączenia"
    echo "     ➜ Zalecane dla produkcji: https://mikr.us/panel/?a=cloud"
    echo ""

    read -p "Wybierz opcję [1-2]: " DB_CHOICE

    case $DB_CHOICE in
        1)
            if [ "$SHARED_BLOCKED" = true ]; then
                echo ""
                echo -e "${RED}❌ $APP_NAME nie działa ze współdzieloną bazą Mikrusa!${NC}"
                echo "   Wymaga rozszerzenia pgcrypto (brak uprawnień w darmowej bazie)."
                echo ""
                echo "   Wykup dedykowany PostgreSQL: https://mikr.us/panel/?a=cloud"
                echo ""
                return 1
            fi
            export DB_SOURCE="shared"
            echo ""
            echo -e "${GREEN}✅ Wybrano: współdzielona baza Mikrus${NC}"
            return 0
            ;;
        2)
            export DB_SOURCE="custom"
            ask_custom_db "$DB_TYPE"
            return $?
            ;;
        *)
            echo -e "${RED}❌ Nieprawidłowy wybór${NC}"
            return 1
            ;;
    esac
}

ask_custom_db() {
    local DB_TYPE="$1"

    echo ""
    echo -e "${YELLOW}📝 Podaj dane własnej bazy danych${NC}"
    echo ""

    if [ "$DB_TYPE" = "postgres" ]; then
        ask_if_empty DB_HOST "Host (np. mws02.mikr.us)"
        ask_if_empty DB_PORT "Port" "5432"
        ask_if_empty DB_NAME "Nazwa bazy"
        ask_if_empty DB_SCHEMA "Schemat" "public"
        ask_if_empty DB_USER "Użytkownik"
        ask_if_empty DB_PASS "Hasło" "" true

    elif [ "$DB_TYPE" = "mysql" ]; then
        ask_if_empty DB_HOST "Host (np. mysql.example.com)"
        ask_if_empty DB_PORT "Port" "3306"
        ask_if_empty DB_NAME "Nazwa bazy"
        ask_if_empty DB_USER "Użytkownik"
        ask_if_empty DB_PASS "Hasło" "" true

    elif [ "$DB_TYPE" = "mongo" ]; then
        ask_if_empty DB_HOST "Host (np. mongo.example.com)"
        ask_if_empty DB_PORT "Port" "27017"
        ask_if_empty DB_NAME "Nazwa bazy"
        ask_if_empty DB_USER "Użytkownik"
        ask_if_empty DB_PASS "Hasło" "" true

    else
        echo -e "${RED}❌ Nieznany typ bazy: $DB_TYPE${NC}"
        return 1
    fi

    # Walidacja
    if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        echo -e "${RED}❌ Wszystkie pola są wymagane${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✅ Dane zapisane${NC}"

    # Eksportuj zmienne
    export DB_HOST DB_PORT DB_NAME DB_SCHEMA DB_USER DB_PASS

    return 0
}

# =============================================================================
# FAZA 2: Pobieranie danych (ciężkie operacje)
# =============================================================================

fetch_database() {
    local DB_TYPE="${1:-postgres}"
    local SSH_ALIAS="${2:-${SSH_ALIAS:-mikrus}}"

    # Jeśli custom - dane już są, nic nie robimy
    if [ "$DB_SOURCE" = "custom" ]; then
        return 0
    fi

    # Shared - pobierz z API
    if [ "$DB_SOURCE" = "shared" ]; then
        fetch_shared_db "$DB_TYPE" "$SSH_ALIAS"
        return $?
    fi

    echo -e "${RED}❌ Nieznane źródło bazy: $DB_SOURCE${NC}"
    return 1
}

fetch_shared_db() {
    local DB_TYPE="$1"
    local SSH_ALIAS="$2"

    # Dry-run mode
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[dry-run] Pobieram dane bazy z API Mikrusa (ssh $SSH_ALIAS)${NC}"
        DB_HOST="[dry-run-host]"
        DB_PORT="5432"
        DB_NAME="[dry-run-db]"
        DB_USER="[dry-run-user]"
        DB_PASS="[dry-run-pass]"
        export DB_HOST DB_PORT DB_NAME DB_USER DB_PASS
        return 0
    fi

    echo "🔑 Pobieram dane bazy z API Mikrusa..."

    # Pobierz klucz API
    local API_KEY=$(ssh "$SSH_ALIAS" 'cat /klucz_api 2>/dev/null' 2>/dev/null)

    if [ -z "$API_KEY" ]; then
        echo -e "${RED}❌ Nie znaleziono klucza API na serwerze!${NC}"
        echo "   Sprawdź czy masz aktywne API: https://mikr.us/panel/?a=api"
        return 1
    fi

    # Pobierz hostname serwera
    local HOSTNAME=$(ssh "$SSH_ALIAS" 'hostname' 2>/dev/null)

    if [ -z "$HOSTNAME" ]; then
        echo -e "${RED}❌ Nie udało się połączyć z serwerem${NC}"
        return 1
    fi

    # Wywołaj API
    local RESPONSE=$(curl -s -d "srv=$HOSTNAME&key=$API_KEY" https://api.mikr.us/db.bash)

    if [ -z "$RESPONSE" ]; then
        echo -e "${RED}❌ Brak odpowiedzi z API Mikrusa${NC}"
        return 1
    fi

    # Parsuj odpowiedź w zależności od typu bazy
    if [ "$DB_TYPE" = "postgres" ]; then
        local SECTION=$(echo "$RESPONSE" | grep -A4 "^psql=")
        DB_HOST=$(echo "$SECTION" | grep 'Server:' | head -1 | sed 's/.*Server: *//' | tr -d '"')
        DB_USER=$(echo "$SECTION" | grep 'login:' | head -1 | sed 's/.*login: *//')
        DB_PASS=$(echo "$SECTION" | grep 'Haslo:' | head -1 | sed 's/.*Haslo: *//')
        DB_NAME=$(echo "$SECTION" | grep 'Baza:' | head -1 | sed 's/.*Baza: *//' | tr -d '"')
        DB_PORT="5432"

        if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ]; then
            echo -e "${RED}❌ Baza PostgreSQL nie jest aktywna!${NC}"
            echo ""
            echo "   Włącz ją w panelu Mikrus:"
            echo -e "   ${BLUE}https://mikr.us/panel/?a=postgres${NC}"
            echo ""
            echo "   Po włączeniu uruchom instalację ponownie."
            return 1
        fi

    elif [ "$DB_TYPE" = "mysql" ]; then
        local SECTION=$(echo "$RESPONSE" | grep -A4 "^mysql=")
        DB_HOST=$(echo "$SECTION" | grep 'Server:' | head -1 | sed 's/.*Server: *//' | tr -d '"')
        DB_USER=$(echo "$SECTION" | grep 'login:' | head -1 | sed 's/.*login: *//')
        DB_PASS=$(echo "$SECTION" | grep 'Haslo:' | head -1 | sed 's/.*Haslo: *//')
        DB_NAME=$(echo "$SECTION" | grep 'Baza:' | head -1 | sed 's/.*Baza: *//' | tr -d '"')
        DB_PORT="3306"

        if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ]; then
            echo -e "${RED}❌ Baza MySQL nie jest aktywna!${NC}"
            echo ""
            echo "   Włącz ją w panelu Mikrus:"
            echo -e "   ${BLUE}https://mikr.us/panel/?a=mysql${NC}"
            echo ""
            echo "   Po włączeniu uruchom instalację ponownie."
            return 1
        fi

    elif [ "$DB_TYPE" = "mongo" ]; then
        local SECTION=$(echo "$RESPONSE" | grep -A6 "^mongo=")
        DB_HOST=$(echo "$SECTION" | grep 'Host:' | head -1 | sed 's/.*Host: *//')
        DB_PORT=$(echo "$SECTION" | grep 'Port:' | head -1 | sed 's/.*Port: *//')
        DB_USER=$(echo "$SECTION" | grep 'Login:' | head -1 | sed 's/.*Login: *//')
        DB_PASS=$(echo "$SECTION" | grep 'Haslo:' | head -1 | sed 's/.*Haslo: *//')
        DB_NAME=$(echo "$SECTION" | grep 'Baza:' | head -1 | sed 's/.*Baza: *//')

        if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ]; then
            echo -e "${RED}❌ Baza MongoDB nie jest aktywna!${NC}"
            echo ""
            echo "   Włącz ją w panelu Mikrus:"
            echo -e "   ${BLUE}https://mikr.us/panel/?a=mongodb${NC}"
            echo ""
            echo "   Po włączeniu uruchom instalację ponownie."
            return 1
        fi
    else
        echo -e "${RED}❌ Nieznany typ bazy: $DB_TYPE${NC}"
        echo "   Obsługiwane: postgres, mysql, mongo"
        return 1
    fi

    echo -e "${GREEN}✅ Dane pobrane z API${NC}"

    # Eksportuj zmienne
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASS

    return 0
}

# =============================================================================
# HELPER: Podsumowanie konfiguracji DB
# =============================================================================

show_db_summary() {
    echo ""
    echo "📋 Konfiguracja bazy danych:"
    echo "   Źródło: $DB_SOURCE"
    echo "   Host:   $DB_HOST"
    echo "   Port:   $DB_PORT"
    echo "   Baza:   $DB_NAME"
    if [ -n "$DB_SCHEMA" ] && [ "$DB_SCHEMA" != "public" ]; then
        echo "   Schema: $DB_SCHEMA"
    fi
    echo "   User:   $DB_USER"
    echo "   Pass:   ****${DB_PASS: -4}"
    echo ""
}

# =============================================================================
# STARY FLOW (kompatybilność wsteczna)
# =============================================================================

setup_database() {
    local DB_TYPE="${1:-postgres}"
    local SSH_ALIAS="${2:-${SSH_ALIAS:-mikrus}}"
    local APP_NAME="${3:-}"

    # Faza 1: zbierz dane
    if ! ask_database "$DB_TYPE" "$APP_NAME"; then
        return 1
    fi

    # Faza 2: pobierz z API (jeśli shared)
    if ! fetch_database "$DB_TYPE" "$SSH_ALIAS"; then
        return 1
    fi

    # Pokaż podsumowanie
    show_db_summary

    return 0
}

# Alias dla kompatybilności
setup_shared_db() {
    DB_SOURCE="shared"
    fetch_shared_db "$@"
}

setup_custom_db() {
    DB_SOURCE="custom"
    ask_custom_db "$@"
}

# Helper do generowania connection string
get_postgres_url() {
    echo "postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
}

get_mongo_url() {
    echo "mongodb://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
}

get_mysql_url() {
    echo "mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
}

# Eksportuj funkcje
export -f ask_database
export -f ask_custom_db
export -f fetch_database
export -f fetch_shared_db
export -f show_db_summary
export -f setup_database
export -f setup_shared_db
export -f setup_custom_db
export -f get_postgres_url
export -f get_mongo_url
export -f get_mysql_url
