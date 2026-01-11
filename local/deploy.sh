#!/bin/bash

# Mikrus Toolbox - Remote Deployer
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/deploy.sh APP [--ssh=ALIAS] [--db-source=shared|custom] [--domain=DOMAIN] [--yes]
#
# Przykłady:
#   ./local/deploy.sh n8n --ssh=hanna                              # interaktywny
#   ./local/deploy.sh n8n --ssh=hanna --db-source=shared --domain=auto --yes  # automatyczny
#   ./local/deploy.sh uptime-kuma --domain-type=local --yes        # bez domeny
#
# FLOW:
#   1. Parsowanie argumentów CLI
#   2. Potwierdzenie użytkownika (skip z --yes)
#   3. FAZA ZBIERANIA - pytania o DB i domenę (skip z CLI)
#   4. "Teraz się zrelaksuj - pracuję..."
#   5. FAZA WYKONANIA - API calls, Docker, instalacja
#   6. Konfiguracja domeny (PO uruchomieniu usługi!)
#   7. Podsumowanie

set -e

# Znajdź katalog repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Załaduj biblioteki
source "$REPO_ROOT/lib/cli-parser.sh"
source "$REPO_ROOT/lib/db-setup.sh"
source "$REPO_ROOT/lib/domain-setup.sh"

# =============================================================================
# CUSTOM HELP
# =============================================================================

show_deploy_help() {
    cat <<EOF
Mikrus Toolbox - Deploy

Użycie:
  ./local/deploy.sh APP [opcje]

Argumenty:
  APP                  Nazwa aplikacji (np. n8n, uptime-kuma) lub ścieżka do skryptu

Opcje SSH:
  --ssh=ALIAS          SSH alias z ~/.ssh/config (domyślnie: mikrus)

Opcje bazy danych:
  --db-source=TYPE     Źródło bazy: shared (API Mikrus) lub custom
  --db-host=HOST       Host bazy danych
  --db-port=PORT       Port bazy (domyślnie: 5432)
  --db-name=NAME       Nazwa bazy danych
  --db-schema=SCHEMA   Schema PostgreSQL (domyślnie: public)
  --db-user=USER       Użytkownik bazy
  --db-pass=PASS       Hasło bazy

Opcje domeny:
  --domain=DOMAIN      Domena aplikacji (lub 'auto' dla Cytrus automatyczny)
  --domain-type=TYPE   Typ: cytrus, cloudflare, local

Tryby:
  --yes, -y            Pomiń wszystkie potwierdzenia
  --dry-run            Pokaż co się wykona bez wykonania
  --help, -h           Pokaż tę pomoc

Przykłady:
  # Interaktywny (pytania o brakujące dane)
  ./local/deploy.sh n8n --ssh=hanna

  # Automatyczny z Cytrus
  ./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=cytrus --domain=auto --yes

  # Automatyczny z Cloudflare
  ./local/deploy.sh n8n --ssh=hanna \\
    --db-source=custom --db-host=psql.example.com \\
    --db-name=n8n --db-user=user --db-pass=secret \\
    --domain-type=cloudflare --domain=n8n.example.com --yes

  # Tylko lokalnie (bez domeny)
  ./local/deploy.sh dockge --ssh=hanna --domain-type=local --yes

  # Dry-run (podgląd bez wykonania)
  ./local/deploy.sh n8n --ssh=hanna --dry-run

EOF
}

# Override show_help z cli-parser
show_help() {
    show_deploy_help
}

# =============================================================================
# PARSOWANIE ARGUMENTÓW
# =============================================================================

load_defaults
parse_args "$@"

# Pierwszy argument pozycyjny = APP
SCRIPT_PATH="${POSITIONAL_ARGS[0]:-}"

if [ -z "$SCRIPT_PATH" ]; then
    echo "Błąd: Nie podano nazwy aplikacji."
    echo ""
    show_deploy_help
    exit 1
fi

# SSH_ALIAS z --ssh lub default
SSH_ALIAS="${SSH_ALIAS:-mikrus}"

# =============================================================================
# RESOLVE APP/SCRIPT PATH
# =============================================================================

APP_NAME=""
if [ -f "$REPO_ROOT/apps/$SCRIPT_PATH/install.sh" ]; then
    echo "💡 Wykryto aplikację: '$SCRIPT_PATH'"
    APP_NAME="$SCRIPT_PATH"
    SCRIPT_PATH="$REPO_ROOT/apps/$SCRIPT_PATH/install.sh"
elif [ -f "$SCRIPT_PATH" ]; then
    :  # Direct file exists
elif [ -f "$REPO_ROOT/$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$REPO_ROOT/$SCRIPT_PATH"
else
    echo "Błąd: Skrypt lub aplikacja '$SCRIPT_PATH' nie znaleziona."
    echo "   Szukano:"
    echo "   - apps/$SCRIPT_PATH/install.sh"
    echo "   - $SCRIPT_PATH"
    exit 1
fi

# =============================================================================
# POTWIERDZENIE
# =============================================================================

REMOTE_HOST=$(ssh -G "$SSH_ALIAS" 2>/dev/null | grep "^hostname " | cut -d' ' -f2)
REMOTE_USER=$(ssh -G "$SSH_ALIAS" 2>/dev/null | grep "^user " | cut -d' ' -f2)
SCRIPT_DISPLAY="${SCRIPT_PATH#$REPO_ROOT/}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️   UWAGA: INSTALACJA NA ZDALNYM SERWERZE!                   ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Serwer:  $REMOTE_USER@$REMOTE_HOST"
echo "║  Skrypt:  $SCRIPT_DISPLAY"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Ostrzeżenie dla Git Bash + MinTTY (przed interaktywnymi pytaniami)
warn_gitbash_mintty

if ! confirm "Czy na pewno chcesz uruchomić ten skrypt na ZDALNYM serwerze?"; then
    echo "Anulowano."
    exit 1
fi

# =============================================================================
# FAZA 0: SPRAWDZANIE ZASOBÓW SERWERA
# =============================================================================

# Wykryj wymagania RAM z docker-compose (memory limit)
REQUIRED_RAM=256  # domyślnie
if grep -q "memory:" "$SCRIPT_PATH" 2>/dev/null; then
    # Przenośna wersja (bez grep -P który nie działa na macOS)
    MEM_LIMIT=$(grep "memory:" "$SCRIPT_PATH" | sed -E 's/[^0-9]*([0-9]+).*/\1/' | head -1)
    if [ -n "$MEM_LIMIT" ]; then
        REQUIRED_RAM=$MEM_LIMIT
    fi
fi

# Wykryj rozmiar obrazu Docker
# 1. Próbuj Docker Hub API (dynamicznie)
# 2. Fallback na IMAGE_SIZE_MB z nagłówka skryptu
REQUIRED_DISK=500  # domyślnie 500MB
IMAGE_SIZE=""
IMAGE_SIZE_SOURCE=""

# Wyciągnij nazwę obrazu z docker-compose w skrypcie
DOCKER_IMAGE=$(grep -E "^[[:space:]]*image:" "$SCRIPT_PATH" 2>/dev/null | head -1 | awk -F'image:' '{gsub(/^[[:space:]]*|[[:space:]]*$/,"",$2); print $2}')

if [ -n "$DOCKER_IMAGE" ]; then
    # Tylko Docker Hub obsługuje nasze API query (nie ghcr.io, quay.io, etc.)
    if [[ "$DOCKER_IMAGE" != *"ghcr.io"* ]] && [[ "$DOCKER_IMAGE" != *"quay.io"* ]] && [[ "$DOCKER_IMAGE" != *"gcr.io"* ]]; then
        # Parsuj image name: owner/repo:tag lub library/repo:tag
        if [[ "$DOCKER_IMAGE" == *"/"* ]]; then
            REPO_OWNER=$(echo "$DOCKER_IMAGE" | cut -d'/' -f1)
            REPO_NAME=$(echo "$DOCKER_IMAGE" | cut -d'/' -f2 | cut -d':' -f1)
            TAG=$(echo "$DOCKER_IMAGE" | grep -o ':[^:]*$' | tr -d ':')
            [ -z "$TAG" ] && TAG="latest"
        else
            # Official image (e.g., redis:alpine)
            REPO_OWNER="library"
            REPO_NAME=$(echo "$DOCKER_IMAGE" | cut -d':' -f1)
            TAG=$(echo "$DOCKER_IMAGE" | grep -o ':[^:]*$' | tr -d ':')
            [ -z "$TAG" ] && TAG="latest"
        fi

        # Próbuj Docker Hub API (timeout 5s)
        API_URL="https://hub.docker.com/v2/repositories/${REPO_OWNER}/${REPO_NAME}/tags/${TAG}"
        COMPRESSED_SIZE=$(curl -sf --max-time 5 "$API_URL" 2>/dev/null | grep -o '"full_size":[0-9]*' | grep -o '[0-9]*')

        if [ -n "$COMPRESSED_SIZE" ] && [ "$COMPRESSED_SIZE" -gt 0 ]; then
            # Compressed * 2.5 ≈ uncompressed size on disk
            IMAGE_SIZE=$((COMPRESSED_SIZE / 1024 / 1024 * 25 / 10))
            IMAGE_SIZE_SOURCE="Docker Hub API"
        fi
    fi
fi

# Fallback na hardcoded IMAGE_SIZE_MB
if [ -z "$IMAGE_SIZE" ]; then
    IMAGE_SIZE=$(grep "^# IMAGE_SIZE_MB=" "$SCRIPT_PATH" 2>/dev/null | sed -E 's/.*IMAGE_SIZE_MB=([0-9]+).*/\1/' | head -1)
    [ -n "$IMAGE_SIZE" ] && IMAGE_SIZE_SOURCE="skrypt"
fi

if [ -n "$IMAGE_SIZE" ]; then
    # Dodaj 20% marginesu na temp files podczas pobierania
    REQUIRED_DISK=$((IMAGE_SIZE + IMAGE_SIZE / 5))
fi

# Sprawdź zasoby na serwerze
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  📊 Sprawdzanie zasobów serwera...                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"

RESOURCES=$(ssh -o ConnectTimeout=10 "$SSH_ALIAS" "free -m | awk '/^Mem:/ {print \$7}'; df -m / | awk 'NR==2 {print \$4}'; free -m | awk '/^Mem:/ {print \$2}'" 2>/dev/null)
AVAILABLE_RAM=$(echo "$RESOURCES" | sed -n '1p')
AVAILABLE_DISK=$(echo "$RESOURCES" | sed -n '2p')
TOTAL_RAM=$(echo "$RESOURCES" | sed -n '3p')

if [ -n "$AVAILABLE_RAM" ] && [ -n "$AVAILABLE_DISK" ]; then
    echo ""
    echo -n "   RAM: ${AVAILABLE_RAM}MB dostępne (z ${TOTAL_RAM}MB)"
    if [ "$AVAILABLE_RAM" -lt "$REQUIRED_RAM" ]; then
        echo -e " ${RED}✗ wymagane: ${REQUIRED_RAM}MB${NC}"
        if [ "$YES_MODE" != "true" ]; then
            echo ""
            echo -e "${RED}   ❌ Za mało RAM! Instalacja może zawiesić serwer.${NC}"
            if ! confirm "   Czy mimo to kontynuować?"; then
                echo "Anulowano."
                exit 1
            fi
        fi
    elif [ "$AVAILABLE_RAM" -lt $((REQUIRED_RAM + 100)) ]; then
        echo -e " ${YELLOW}⚠ będzie ciasno${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi

    echo -n "   Dysk: ${AVAILABLE_DISK}MB wolne"
    if [ "$AVAILABLE_DISK" -lt "$REQUIRED_DISK" ]; then
        echo -e " ${RED}✗ wymagane: ~${REQUIRED_DISK}MB${NC}"
        echo ""
        echo -e "${RED}   ❌ Za mało miejsca na dysku!${NC}"
        if [ -n "$IMAGE_SIZE_SOURCE" ]; then
            echo -e "${RED}   Obraz Docker: ~${IMAGE_SIZE}MB (${IMAGE_SIZE_SOURCE}) + temp files${NC}"
        else
            echo -e "${RED}   Obraz Docker zajmie ~500MB + temp files.${NC}"
        fi
        if [ "$YES_MODE" == "true" ]; then
            echo -e "${RED}   Przerywam instalację (--yes mode).${NC}"
            exit 1
        fi
        if ! confirm "   Czy mimo to kontynuować?"; then
            echo "Anulowano."
            exit 1
        fi
    elif [ "$AVAILABLE_DISK" -lt $((REQUIRED_DISK + 500)) ]; then
        echo -e " ${YELLOW}⚠ mało miejsca (potrzeba ~${REQUIRED_DISK}MB)${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi

    # Ostrzeżenie dla ciężkich aplikacji na małym RAM
    if [ "$REQUIRED_RAM" -ge 400 ] && [ "$TOTAL_RAM" -lt 2000 ]; then
        echo ""
        echo -e "   ${YELLOW}⚠ Ta aplikacja wymaga dużo RAM (${REQUIRED_RAM}MB).${NC}"
        echo -e "   ${YELLOW}  Zalecany plan: Mikrus 2.0+ (2GB RAM)${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠ Nie udało się sprawdzić zasobów${NC}"
fi

# =============================================================================
# FAZA 0.5: SPRAWDZANIE PORTÓW
# =============================================================================

# Pobierz domyślny port z install.sh
# Obsługuje: PORT=3000 i PORT=${PORT:-3000}
DEFAULT_PORT=$(grep -E "^PORT=" "$SCRIPT_PATH" 2>/dev/null | head -1 | sed -E 's/.*[=:-]([0-9]+).*/\1/')
PORT_OVERRIDE=""

if [ -n "$DEFAULT_PORT" ]; then
    # Sprawdź czy port jest zajęty na serwerze
    PORT_IN_USE=$(ssh -o ConnectTimeout=5 "$SSH_ALIAS" "ss -tlnp 2>/dev/null | grep -q ':${DEFAULT_PORT} ' && echo 'yes' || echo 'no'" 2>/dev/null)

    if [ "$PORT_IN_USE" == "yes" ]; then
        echo ""
        echo -e "   ${YELLOW}⚠ Port $DEFAULT_PORT jest zajęty!${NC}"

        # Znajdź wolny port (start od DEFAULT_PORT+1, max 10 prób)
        for i in {1..10}; do
            TEST_PORT=$((DEFAULT_PORT + i))
            PORT_FREE=$(ssh -o ConnectTimeout=5 "$SSH_ALIAS" "ss -tlnp 2>/dev/null | grep -q ':${TEST_PORT} ' && echo 'no' || echo 'yes'" 2>/dev/null)
            if [ "$PORT_FREE" == "yes" ]; then
                PORT_OVERRIDE=$TEST_PORT
                echo -e "   ${GREEN}✓ Używam portu $PORT_OVERRIDE zamiast $DEFAULT_PORT${NC}"
                break
            fi
        done

        if [ -z "$PORT_OVERRIDE" ]; then
            echo -e "   ${RED}❌ Nie znaleziono wolnego portu w zakresie ${DEFAULT_PORT}-$((DEFAULT_PORT + 10))${NC}"
            if [ "$YES_MODE" != "true" ]; then
                if ! confirm "   Kontynuować mimo to?"; then
                    echo "Anulowano."
                    exit 1
                fi
            fi
        fi
    fi
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

    if ! ask_database "$DB_TYPE" "$APP_NAME"; then
        echo "Błąd: Konfiguracja bazy danych nie powiodła się."
        exit 1
    fi
fi

# Sprawdź czy to aplikacja i wymaga domeny
if [[ "$SCRIPT_DISPLAY" == apps/* ]]; then
    APP_PORT=$(grep -E "^PORT=" "$SCRIPT_PATH" | head -1 | sed -E 's/.*[=:-]([0-9]+).*/\1/')

    # Sprawdź też czy skrypt wymaga DOMAIN (np. static sites bez Dockera)
    REQUIRES_DOMAIN_UPFRONT=false
    if grep -q 'if \[ -z "\$DOMAIN" \]' "$SCRIPT_PATH" 2>/dev/null; then
        REQUIRES_DOMAIN_UPFRONT=true
        APP_PORT="${APP_PORT:-443}"  # Static sites use HTTPS via Caddy
    fi

    if [ -n "$APP_PORT" ] || [ "$REQUIRES_DOMAIN_UPFRONT" = true ]; then
        NEEDS_DOMAIN=true

        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  🌐 Konfiguracja domeny dla: $APP_NAME                         ║"
        echo "╚════════════════════════════════════════════════════════════════╝"

        if ! ask_domain "$APP_NAME" "$APP_PORT" "$SSH_ALIAS"; then
            echo ""
            echo "Błąd: Konfiguracja domeny nie powiodła się."
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
    if ! fetch_database "$DB_TYPE" "$SSH_ALIAS"; then
        echo "Błąd: Nie udało się pobrać danych bazy."
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

# Przygotuj zmienną DOMAIN do przekazania
DOMAIN_ENV=""
CYTRUS_PLACEHOLDER="pending.byst.re"
if [ "$NEEDS_DOMAIN" = true ] && [ "$DOMAIN_TYPE" != "local" ] && [ -n "$DOMAIN" ]; then
    if [ "$DOMAIN" = "-" ]; then
        # Dla Cytrus z automatyczną domeną, używamy placeholdera
        # Po instalacji zostanie zaktualizowany prawdziwą domeną
        DOMAIN_ENV="DOMAIN='$CYTRUS_PLACEHOLDER'"
    else
        DOMAIN_ENV="DOMAIN='$DOMAIN'"
    fi
fi

# Przygotuj zmienną PORT do przekazania (jeśli nadpisany)
PORT_ENV=""
if [ -n "$PORT_OVERRIDE" ]; then
    PORT_ENV="PORT='$PORT_OVERRIDE'"
    # Zaktualizuj też APP_PORT dla configure_domain
    APP_PORT="$PORT_OVERRIDE"
fi

# Dry-run mode
if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}[dry-run] Symulacja wykonania:${NC}"
    echo "  scp $SCRIPT_PATH $SSH_ALIAS:/tmp/mikrus-deploy-$$.sh"
    echo "  ssh -t $SSH_ALIAS \"export DEPLOY_SSH_ALIAS='$SSH_ALIAS' $PORT_ENV $DB_ENV_VARS $DOMAIN_ENV; bash '/tmp/mikrus-deploy-$$.sh'\""
    echo ""
    echo -e "${BLUE}[dry-run] Po instalacji:${NC}"
    if [ "$NEEDS_DOMAIN" = true ]; then
        echo "  configure_domain $APP_PORT $SSH_ALIAS"
    fi
    echo ""
    echo -e "${GREEN}[dry-run] Zakończono symulację.${NC}"
    exit 0
fi

# Upload script to server and execute
echo "🚀 Uruchamiam instalację na serwerze..."
echo ""

REMOTE_SCRIPT="/tmp/mikrus-deploy-$$.sh"
scp -q "$SCRIPT_PATH" "$SSH_ALIAS:$REMOTE_SCRIPT"

if ssh -t "$SSH_ALIAS" "export DEPLOY_SSH_ALIAS='$SSH_ALIAS' SSH_ALIAS='$SSH_ALIAS' $PORT_ENV $DB_ENV_VARS $DOMAIN_ENV; bash '$REMOTE_SCRIPT'; EXIT_CODE=\$?; rm -f '$REMOTE_SCRIPT'; exit \$EXIT_CODE"; then
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

# Sprawdź czy install.sh zapisał port (dla dynamicznych portów jak Docker static sites)
INSTALLED_PORT=$(ssh "$SSH_ALIAS" "cat /tmp/app_port 2>/dev/null; rm -f /tmp/app_port" 2>/dev/null)
if [ -n "$INSTALLED_PORT" ]; then
    APP_PORT="$INSTALLED_PORT"
fi

if [ "$NEEDS_DOMAIN" = true ] && [ "$DOMAIN_TYPE" != "local" ]; then
    echo ""
    ORIGINAL_DOMAIN="$DOMAIN"  # Zapamiętaj czy był "-" (automatyczny)
    if configure_domain "$APP_PORT" "$SSH_ALIAS"; then
        # Dla Cytrus z automatyczną domeną - zaktualizuj config prawdziwą domeną
        # Po configure_domain(), zmienna DOMAIN zawiera przydzieloną domenę
        if [ "$ORIGINAL_DOMAIN" = "-" ] && [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
            echo "🔄 Aktualizuję konfigurację z prawdziwą domeną: $DOMAIN"
            if [ "$REQUIRES_DOMAIN_UPFRONT" = true ]; then
                # Static sites - update Caddyfile
                ssh "$SSH_ALIAS" "sudo sed -i 's|$CYTRUS_PLACEHOLDER|$DOMAIN|g' /etc/caddy/Caddyfile && sudo systemctl reload caddy" 2>/dev/null
            else
                # Docker apps - update docker-compose
                ssh "$SSH_ALIAS" "cd /opt/stacks/$APP_NAME && sed -i 's|$CYTRUS_PLACEHOLDER|$DOMAIN|g' docker-compose.yaml && docker compose up -d" 2>/dev/null
            fi
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
    echo -e "   ${BLUE}ssh -L $APP_PORT:localhost:$APP_PORT $SSH_ALIAS${NC}"
    echo "   Potem otwórz: http://localhost:$APP_PORT"
elif [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo ""
    echo -e "🌐 Aplikacja dostępna pod: ${BLUE}https://$DOMAIN${NC}"
fi

echo ""
