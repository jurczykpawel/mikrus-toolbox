#!/bin/bash

# Mikrus Toolbox - Database Setup Helper
# Używany przez skrypty instalacyjne do konfiguracji bazy danych.
# Author: Paweł (Lazy Engineer)
#
# NOWY FLOW (fazy):
#   1. ask_database()    - zbiera wybór użytkownika (bez API)
#   2. fetch_database()  - pobiera dane z API (ciężka operacja)
#
# STARY FLOW (kompatybilność wsteczna):
#   setup_database() - robi wszystko na raz
#
# Po wywołaniu dostępne zmienne:
#   $DB_HOST, $DB_PORT, $DB_NAME, $DB_USER, $DB_PASS, $DB_SOURCE

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Zmienne eksportowane (nie resetuj jeśli już ustawione)
export DB_HOST="${DB_HOST:-}"
export DB_PORT="${DB_PORT:-}"
export DB_NAME="${DB_NAME:-}"
export DB_SCHEMA="${DB_SCHEMA:-}"  # schemat PostgreSQL (izolacja tabel per aplikacja)
export DB_USER="${DB_USER:-}"
export DB_PASS="${DB_PASS:-}"
export DB_SOURCE="${DB_SOURCE:-}"  # "shared" lub "custom"

# Aplikacje wymagające pgcrypto (nie działają ze współdzieloną bazą Mikrusa)
# n8n od wersji 1.121+ wymaga gen_random_uuid() które potrzebuje pgcrypto lub PostgreSQL 13+
REQUIRES_PGCRYPTO="umami n8n"

# =============================================================================
# FAZA 1: Zbieranie informacji (bez API)
# =============================================================================

ask_database() {
    local DB_TYPE="${1:-postgres}"
    local APP_NAME="${2:-}"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🗄️  Konfiguracja bazy danych ($DB_TYPE)"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Gdzie ma być baza danych?"
    echo ""

    # Sprawdź czy aplikacja wymaga pgcrypto
    local SHARED_BLOCKED=false
    if [[ " $REQUIRES_PGCRYPTO " == *" $APP_NAME "* ]]; then
        SHARED_BLOCKED=true
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
        read -p "Host (np. mws02.mikr.us): " DB_HOST
        read -p "Port [5432]: " DB_PORT
        DB_PORT="${DB_PORT:-5432}"
        read -p "Nazwa bazy: " DB_NAME
        read -p "Schemat [public]: " DB_SCHEMA
        DB_SCHEMA="${DB_SCHEMA:-public}"
        read -p "Użytkownik: " DB_USER
        read -sp "Hasło: " DB_PASS
        echo ""
    elif [ "$DB_TYPE" = "mysql" ]; then
        read -p "Host (np. mysql.example.com): " DB_HOST
        read -p "Port [3306]: " DB_PORT
        DB_PORT="${DB_PORT:-3306}"
        read -p "Nazwa bazy: " DB_NAME
        read -p "Użytkownik: " DB_USER
        read -sp "Hasło: " DB_PASS
        echo ""
    elif [ "$DB_TYPE" = "mongo" ]; then
        read -p "Host (np. mongo.example.com): " DB_HOST
        read -p "Port [27017]: " DB_PORT
        DB_PORT="${DB_PORT:-27017}"
        read -p "Nazwa bazy: " DB_NAME
        read -p "Użytkownik: " DB_USER
        read -sp "Hasło: " DB_PASS
        echo ""
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
    local SSH_ALIAS="${2:-mikrus}"

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
# STARY FLOW (kompatybilność wsteczna)
# =============================================================================

setup_database() {
    local DB_TYPE="${1:-postgres}"
    local SSH_ALIAS="${2:-mikrus}"
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
    echo ""
    echo "📋 Konfiguracja bazy danych:"
    echo "   Host: $DB_HOST"
    echo "   Port: $DB_PORT"
    echo "   Baza: $DB_NAME"
    echo "   User: $DB_USER"
    echo "   Pass: ****${DB_PASS: -4}"
    echo ""

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
export -f setup_database
export -f setup_shared_db
export -f setup_custom_db
export -f get_postgres_url
export -f get_mongo_url
export -f get_mysql_url
