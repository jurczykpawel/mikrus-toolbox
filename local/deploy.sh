#!/bin/bash

# Mikrus Toolbox - Remote Deployer
# Usage: ./local/deploy.sh <script_or_app> [ssh_alias]
# Example: ./local/deploy.sh system/docker-setup.sh
# Example: ./local/deploy.sh n8n hanna          # deploy to 'hanna' server
#
# FLOW:
#   1. Potwierdzenie użytkownika
#   2. FAZA ZBIERANIA - pytania o DB i domenę (bez API)
#   3. Komunikat "teraz się zrelaksuj"
#   4. FAZA WYKONANIA - API calls, Docker, instalacja
#   5. Konfiguracja domeny Cytrus (PO uruchomieniu usługi!)
#   6. Podsumowanie

SCRIPT_PATH="$1"
TARGET="${2:-mikrus}" # Second argument or default to 'mikrus'

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Validate input
if [ -z "$SCRIPT_PATH" ]; then
  echo "❌ Error: No script or app name specified."
  echo ""
  echo "Usage: $0 <app_or_script> [serwer]"
  echo ""
  echo "Przykłady:"
  echo "  $0 n8n                    # instaluje n8n na 'mikrus' (domyślny)"
  echo "  $0 n8n hanna              # instaluje n8n na 'hanna'"
  echo "  $0 system/docker-setup.sh # uruchamia skrypt na 'mikrus'"
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Check if it's a short app name (Smart Mode)
APP_NAME=""
if [ -f "$REPO_ROOT/apps/$SCRIPT_PATH/install.sh" ]; then
    echo "💡 Detected App Name: '$SCRIPT_PATH'. Using installer."
    APP_NAME="$SCRIPT_PATH"
    SCRIPT_PATH="$REPO_ROOT/apps/$SCRIPT_PATH/install.sh"
elif [ -f "$SCRIPT_PATH" ]; then
    # Direct file exists
    :
elif [ -f "$REPO_ROOT/$SCRIPT_PATH" ]; then
    # Relative to root exists
    SCRIPT_PATH="$REPO_ROOT/$SCRIPT_PATH"
else
    echo "❌ Error: Script or App '$SCRIPT_PATH' not found."
    echo "   Searched for:"
    echo "   - apps/$SCRIPT_PATH/install.sh"
    echo "   - $SCRIPT_PATH"
    exit 1
fi

# 2. Get remote server info for confirmation
REMOTE_HOST=$(ssh -G "$TARGET" 2>/dev/null | grep "^hostname " | cut -d' ' -f2)
REMOTE_USER=$(ssh -G "$TARGET" 2>/dev/null | grep "^user " | cut -d' ' -f2)

# 3. Big warning and confirmation
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️   UWAGA: INSTALACJA NA ZDALNYM SERWERZE!                   ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Serwer:  $REMOTE_USER@$REMOTE_HOST"
SCRIPT_DISPLAY="${SCRIPT_PATH#$REPO_ROOT/}"
echo "║  Skrypt:  $SCRIPT_DISPLAY"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
read -p "Czy na pewno chcesz uruchomić ten skrypt na ZDALNYM serwerze? (t/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[TtYy]$ ]]; then
    echo "Anulowano."
    exit 1
fi

# =============================================================================
# FAZA 1: ZBIERANIE INFORMACJI (bez API/ciężkich operacji)
# =============================================================================

# Zmienne do przekazania
DB_ENV_VARS=""
DB_TYPE=""
NEEDS_DB=false
NEEDS_DOMAIN=false
APP_PORT=""

# Sprawdź czy aplikacja wymaga bazy danych
if grep -qiE "DB_HOST|DATABASE_URL" "$SCRIPT_PATH" 2>/dev/null; then
    NEEDS_DB=true

    # Wykryj typ bazy
    if grep -qi "mysql" "$SCRIPT_PATH"; then
        DB_TYPE="mysql"
    elif grep -qi "mongo" "$SCRIPT_PATH"; then
        DB_TYPE="mongo"
    else
        DB_TYPE="postgres"
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🗄️  Ta aplikacja wymaga bazy danych ($DB_TYPE)               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"

    source "$REPO_ROOT/lib/db-setup.sh"
    if ! ask_database "$DB_TYPE" "$APP_NAME"; then
        echo "❌ Konfiguracja bazy danych nie powiodła się."
        exit 1
    fi
fi

# Sprawdź czy to aplikacja i wymaga domeny
if [[ "$SCRIPT_DISPLAY" == apps/* ]]; then
    APP_PORT=$(grep -E "^PORT=" "$SCRIPT_PATH" | head -1 | cut -d'=' -f2)

    if [ -n "$APP_PORT" ]; then
        NEEDS_DOMAIN=true

        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  🌐 Konfiguracja domeny dla: $APP_NAME                         ║"
        echo "╚════════════════════════════════════════════════════════════════╝"

        source "$REPO_ROOT/lib/domain-setup.sh"
        if ! ask_domain "$APP_NAME" "$APP_PORT" "$TARGET"; then
            echo ""
            echo "❌ Konfiguracja domeny nie powiodła się."
            exit 1
        fi
    fi
fi

# =============================================================================
# FAZA 2: WYKONANIE (ciężkie operacje)
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ☕ Teraz się zrelaksuj - pracuję...                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Pobierz dane bazy z API (jeśli shared)
if [ "$NEEDS_DB" = true ]; then
    source "$REPO_ROOT/lib/db-setup.sh"
    if ! fetch_database "$DB_TYPE" "$TARGET"; then
        echo "❌ Nie udało się pobrać danych bazy."
        exit 1
    fi

    # Przygotuj zmienne środowiskowe
    DB_ENV_VARS="DB_HOST='$DB_HOST' DB_PORT='$DB_PORT' DB_NAME='$DB_NAME' DB_SCHEMA='$DB_SCHEMA' DB_USER='$DB_USER' DB_PASS='$DB_PASS'"

    echo ""
    echo "📋 Baza danych:"
    echo "   Host: $DB_HOST"
    echo "   Baza: $DB_NAME"
    echo ""
fi

# Przygotuj zmienną DOMAIN do przekazania (jeśli nie local)
DOMAIN_ENV=""
CYTRUS_PLACEHOLDER="pending.cytrus.local"
if [ "$NEEDS_DOMAIN" = true ] && [ "$DOMAIN_TYPE" != "local" ] && [ -n "$DOMAIN" ]; then
    if [ "$DOMAIN" = "-" ]; then
        # Dla Cytrus z automatyczną domeną, używamy placeholdera
        # Po instalacji zostanie zaktualizowany prawdziwą domeną
        DOMAIN_ENV="DOMAIN='$CYTRUS_PLACEHOLDER'"
    else
        DOMAIN_ENV="DOMAIN='$DOMAIN'"
    fi
fi

# Upload script to server and execute
echo "🚀 Uruchamiam instalację na serwerze..."
echo ""

REMOTE_SCRIPT="/tmp/mikrus-deploy-$$.sh"
scp -q "$SCRIPT_PATH" "$TARGET:$REMOTE_SCRIPT"

if ssh -t "$TARGET" "export DEPLOY_SSH_ALIAS='$TARGET' $DB_ENV_VARS $DOMAIN_ENV; bash '$REMOTE_SCRIPT'; EXIT_CODE=\$?; rm -f '$REMOTE_SCRIPT'; exit \$EXIT_CODE"; then
    echo ""
    echo -e "${GREEN}✅ Instalacja zakończona pomyślnie${NC}"
else
    echo ""
    echo -e "${RED}❌ Instalacja NIEUDANA! Sprawdź błędy powyżej.${NC}"
    exit 1
fi

# =============================================================================
# FAZA 3: KONFIGURACJA DOMENY (po uruchomieniu usługi!)
# =============================================================================

if [ "$NEEDS_DOMAIN" = true ] && [ "$DOMAIN_TYPE" != "local" ]; then
    echo ""
    source "$REPO_ROOT/lib/domain-setup.sh"
    ORIGINAL_DOMAIN="$DOMAIN"  # Zapamiętaj czy był "-" (automatyczny)
    if configure_domain "$APP_PORT" "$TARGET"; then
        # Dla Cytrus z automatyczną domeną - zaktualizuj config prawdziwą domeną
        # Po configure_domain(), zmienna DOMAIN zawiera przydzieloną domenę
        if [ "$ORIGINAL_DOMAIN" = "-" ] && [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
            echo "🔄 Aktualizuję konfigurację z prawdziwą domeną: $DOMAIN"
            ssh "$TARGET" "cd /opt/stacks/$APP_NAME && sed -i 's|$CYTRUS_PLACEHOLDER|$DOMAIN|g' docker-compose.yaml && docker compose up -d" 2>/dev/null
            # Wywołaj mikrus-expose z prawdziwą domeną (jeśli dostępny)
            ssh "$TARGET" "command -v mikrus-expose &>/dev/null && mikrus-expose '$DOMAIN' '$APP_PORT'" 2>/dev/null || true
        fi
        # Poczekaj aż domena zacznie odpowiadać (timeout 90s)
        wait_for_domain 90
    else
        echo ""
        echo -e "${YELLOW}⚠️  Usługa działa, ale konfiguracja domeny nie powiodła się.${NC}"
        echo "   Możesz skonfigurować domenę ręcznie później."
    fi
fi

# =============================================================================
# PODSUMOWANIE
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🎉 GOTOWE!                                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"

if [ "$DOMAIN_TYPE" = "local" ]; then
    echo ""
    echo "📋 Dostęp przez tunel SSH:"
    echo -e "   ${BLUE}ssh -L $APP_PORT:localhost:$APP_PORT $TARGET${NC}"
    echo "   Potem otwórz: http://localhost:$APP_PORT"
elif [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo ""
    echo -e "🌐 Aplikacja dostępna pod: ${BLUE}https://$DOMAIN${NC}"
fi

echo ""
