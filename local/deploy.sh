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

    # Sprawdź czy schemat już istnieje (ostrzeżenie dla użytkownika)
    if [ "$DB_TYPE" = "postgres" ]; then
        if ! warn_if_schema_exists "$SSH_ALIAS" "$APP_NAME"; then
            echo "Instalacja anulowana przez użytkownika."
            exit 1
        fi
    fi

    # Przygotuj zmienne środowiskowe
    DB_ENV_VARS="DB_HOST='$DB_HOST' DB_PORT='$DB_PORT' DB_NAME='$DB_NAME' DB_SCHEMA='$DB_SCHEMA' DB_USER='$DB_USER' DB_PASS='$DB_PASS'"

    echo ""
    echo "📋 Baza danych:"
    echo "   Host: $DB_HOST"
    echo "   Baza: $DB_NAME"
    if [ -n "$DB_SCHEMA" ] && [ "$DB_SCHEMA" != "public" ]; then
        echo "   Schemat: $DB_SCHEMA"
    fi
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

# Przekaż dodatkowe zmienne środowiskowe (dla specjalnych aplikacji jak Cap)
EXTRA_ENV=""
[ -n "$USE_LOCAL_MINIO" ] && EXTRA_ENV="$EXTRA_ENV USE_LOCAL_MINIO='$USE_LOCAL_MINIO'"
[ -n "$S3_ENDPOINT" ] && EXTRA_ENV="$EXTRA_ENV S3_ENDPOINT='$S3_ENDPOINT'"
[ -n "$S3_ACCESS_KEY" ] && EXTRA_ENV="$EXTRA_ENV S3_ACCESS_KEY='$S3_ACCESS_KEY'"
[ -n "$S3_SECRET_KEY" ] && EXTRA_ENV="$EXTRA_ENV S3_SECRET_KEY='$S3_SECRET_KEY'"
[ -n "$S3_BUCKET" ] && EXTRA_ENV="$EXTRA_ENV S3_BUCKET='$S3_BUCKET'"
[ -n "$S3_REGION" ] && EXTRA_ENV="$EXTRA_ENV S3_REGION='$S3_REGION'"
[ -n "$S3_PUBLIC_URL" ] && EXTRA_ENV="$EXTRA_ENV S3_PUBLIC_URL='$S3_PUBLIC_URL'"
[ -n "$MYSQL_ROOT_PASS" ] && EXTRA_ENV="$EXTRA_ENV MYSQL_ROOT_PASS='$MYSQL_ROOT_PASS'"
[ -n "$DOMAIN_PUBLIC" ] && EXTRA_ENV="$EXTRA_ENV DOMAIN_PUBLIC='$DOMAIN_PUBLIC'"

# Dry-run mode
if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}[dry-run] Symulacja wykonania:${NC}"
    echo "  scp $SCRIPT_PATH $SSH_ALIAS:/tmp/mikrus-deploy-$$.sh"
    echo "  ssh -t $SSH_ALIAS \"export DEPLOY_SSH_ALIAS='$SSH_ALIAS' $PORT_ENV $DB_ENV_VARS $DOMAIN_ENV $EXTRA_ENV; bash '/tmp/mikrus-deploy-$$.sh'\""
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

# Dla GateFlow - konfiguracja Supabase lokalnie (własna implementacja CLI flow)
if [ "$APP_NAME" = "gateflow" ] && [ -z "$SUPABASE_URL" ]; then
    echo "════════════════════════════════════════════════════════════════"
    echo "📋 KONFIGURACJA SUPABASE"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Generuj klucze ECDH (P-256)
    TEMP_DIR=$(mktemp -d)
    openssl ecparam -name prime256v1 -genkey -noout -out "$TEMP_DIR/private.pem" 2>/dev/null
    openssl ec -in "$TEMP_DIR/private.pem" -pubout -out "$TEMP_DIR/public.pem" 2>/dev/null

    # Pobierz publiczny klucz - 65 bajtów (04 + X + Y) w formacie HEX
    PUBLIC_KEY_RAW=$(openssl ec -in "$TEMP_DIR/private.pem" -pubout -outform DER 2>/dev/null | dd bs=1 skip=26 2>/dev/null | xxd -p | tr -d '\n')

    # Generuj session ID (UUID v4) i token name
    SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    TOKEN_NAME="mikrus_toolbox_$(hostname | tr '.' '_')_$(date +%s)"

    # Buduj URL logowania
    LOGIN_URL="https://supabase.com/dashboard/cli/login?session_id=${SESSION_ID}&token_name=${TOKEN_NAME}&public_key=${PUBLIC_KEY_RAW}"

    echo "🔐 Logowanie do Supabase"
    echo ""
    echo "   Za chwilę otworzy się przeglądarka ze stroną logowania Supabase."
    echo "   Po zalogowaniu zobaczysz 8-znakowy kod weryfikacyjny."
    echo "   Skopiuj go i wklej tutaj."
    echo ""
    read -p "   Naciśnij Enter aby otworzyć przeglądarkę..." _

    if command -v open &>/dev/null; then
        open "$LOGIN_URL"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$LOGIN_URL"
    else
        echo ""
        echo "   Nie mogę otworzyć przeglądarki automatycznie."
        echo "   Otwórz ręcznie: $LOGIN_URL"
    fi

    echo ""
    read -p "Wklej kod weryfikacyjny: " DEVICE_CODE

    # Polluj endpoint po token
    echo ""
    echo "🔑 Pobieram token..."
    POLL_URL="https://api.supabase.com/platform/cli/login/${SESSION_ID}?device_code=${DEVICE_CODE}"

    TOKEN_RESPONSE=$(curl -s "$POLL_URL")

    if echo "$TOKEN_RESPONSE" | grep -q '"access_token"'; then
        echo "   ✓ Token otrzymany, deszyfruję..."

        # Token w odpowiedzi - potrzebujemy odszyfrować
        ENCRYPTED_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
        SERVER_PUBLIC_KEY=$(echo "$TOKEN_RESPONSE" | grep -o '"public_key":"[^"]*"' | cut -d'"' -f4)
        NONCE=$(echo "$TOKEN_RESPONSE" | grep -o '"nonce":"[^"]*"' | cut -d'"' -f4)

        # Deszyfrowanie ECDH + AES-GCM
        if command -v node &>/dev/null; then
            # Zapisz dane do plików tymczasowych
            echo "$SERVER_PUBLIC_KEY" > "$TEMP_DIR/server_pubkey.hex"
            echo "$NONCE" > "$TEMP_DIR/nonce.hex"
            echo "$ENCRYPTED_TOKEN" > "$TEMP_DIR/encrypted.hex"

            SUPABASE_TOKEN=$(TEMP_DIR="$TEMP_DIR" node << 'NODESCRIPT'
const crypto = require('crypto');
const fs = require('fs');

const tempDir = process.env.TEMP_DIR;
const privateKeyPem = fs.readFileSync(tempDir + '/private.pem', 'utf8');
const serverPubKeyHex = fs.readFileSync(tempDir + '/server_pubkey.hex', 'utf8').trim();
const nonceHex = fs.readFileSync(tempDir + '/nonce.hex', 'utf8').trim();
const encryptedHex = fs.readFileSync(tempDir + '/encrypted.hex', 'utf8').trim();

// Dekoduj hex
const serverPubKey = Buffer.from(serverPubKeyHex, 'hex');
const nonce = Buffer.from(nonceHex, 'hex');
const encrypted = Buffer.from(encryptedHex, 'hex');

// Wyciągnij raw private key z PEM (ostatnie 32 bajty z SEC1/PKCS8)
const privKeyObj = crypto.createPrivateKey(privateKeyPem);
const privKeyDer = privKeyObj.export({type: 'sec1', format: 'der'});
// SEC1 format: 30 len 02 01 01 04 20 [32 bytes private key] ...
const privKeyRaw = privKeyDer.slice(7, 39);

// ECDH z createECDH - przyjmuje raw bytes
const ecdh = crypto.createECDH('prime256v1');
ecdh.setPrivateKey(privKeyRaw);
const sharedSecret = ecdh.computeSecret(serverPubKey);

// Klucz AES = shared secret (32 bajty)
const key = sharedSecret;

// Deszyfruj AES-GCM
const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce);
const tag = encrypted.slice(-16);
const ciphertext = encrypted.slice(0, -16);
decipher.setAuthTag(tag);
const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
console.log(decrypted.toString('utf8'));
NODESCRIPT
            ) || true
        else
            echo "   Brak Node.js - nie mogę odszyfrować"
        fi

        if [ -z "$SUPABASE_TOKEN" ] || echo "$SUPABASE_TOKEN" | grep -qiE "error|node:|Error"; then
            echo ""
            echo "⚠️  Nie udało się odszyfrować tokena automatycznie."
            echo "   Ale token został utworzony w Supabase! Pobierzemy go ręcznie."
            echo ""
            echo "   Krok po kroku:"
            echo "   1. Za chwilę otworzy się strona z tokenami Supabase"
            echo "   2. Kliknij 'Generate new token'"
            echo "   3. Nadaj mu nazwę (np. mikrus) i kliknij 'Generate token'"
            echo "   4. Skopiuj wygenerowany token (sbp_...) i wklej tutaj"
            echo ""
            echo "   UWAGA: Istniejących tokenów nie można skopiować - trzeba wygenerować nowy!"
            echo ""
            read -p "   Naciśnij Enter aby otworzyć stronę z tokenami..." _
            if command -v open &>/dev/null; then
                open "https://supabase.com/dashboard/account/tokens"
            elif command -v xdg-open &>/dev/null; then
                xdg-open "https://supabase.com/dashboard/account/tokens"
            else
                echo "   Otwórz: https://supabase.com/dashboard/account/tokens"
            fi
            echo ""
            read -p "Wklej token (sbp_...): " SUPABASE_TOKEN
        else
            echo "   ✅ Token odszyfrowany!"
        fi
    elif echo "$TOKEN_RESPONSE" | grep -q "Cloudflare"; then
        echo "⚠️  Cloudflare blokuje request. Wygeneruj token ręcznie."
        echo ""
        echo "   1. Kliknij 'Generate new token'"
        echo "   2. Nadaj mu nazwę (np. mikrus) i kliknij 'Generate token'"
        echo "   3. Skopiuj wygenerowany token (sbp_...)"
        echo ""
        if command -v open &>/dev/null; then
            open "https://supabase.com/dashboard/account/tokens"
        fi
        read -p "Wklej token (sbp_...): " SUPABASE_TOKEN
    else
        echo "❌ Błąd: $TOKEN_RESPONSE"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    rm -rf "$TEMP_DIR"

    # Mamy token - pobierz projekty
    if [ -n "$SUPABASE_TOKEN" ]; then
        echo ""
        echo "📋 Pobieram listę projektów..."
        PROJECTS=$(curl -s -H "Authorization: Bearer $SUPABASE_TOKEN" "https://api.supabase.com/v1/projects")

        if echo "$PROJECTS" | grep -q '"id"'; then
            echo ""
            echo "Twoje projekty Supabase:"
            echo ""

            # Parsuj projekty do tablicy
            PROJECT_IDS=()
            PROJECT_NAMES=()
            i=1

            # Użyj jq jeśli dostępne, inaczej grep/sed
            if command -v jq &>/dev/null; then
                while IFS=$'\t' read -r proj_id proj_name; do
                    PROJECT_IDS+=("$proj_id")
                    PROJECT_NAMES+=("$proj_name")
                    echo "   $i) $proj_name ($proj_id)"
                    ((i++))
                done < <(echo "$PROJECTS" | jq -r '.[] | "\(.id)\t\(.name)"')
            else
                # Fallback bez jq - parsuj każdy obiekt osobno
                while read -r proj_id; do
                    # Znajdź name dla tego id w JSON
                    proj_name=$(echo "$PROJECTS" | grep -o "\"id\":\"$proj_id\"[^}]*\"name\":\"[^\"]*\"" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
                    if [ -z "$proj_name" ]; then
                        # Może name jest przed id
                        proj_name=$(echo "$PROJECTS" | grep -o "\"name\":\"[^\"]*\"[^}]*\"id\":\"$proj_id\"" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
                    fi
                    PROJECT_IDS+=("$proj_id")
                    PROJECT_NAMES+=("$proj_name")
                    echo "   $i) $proj_name ($proj_id)"
                    ((i++))
                done < <(echo "$PROJECTS" | grep -oE '"id":"[^"]+"' | cut -d'"' -f4)
            fi

            echo ""
            read -p "Wybierz numer projektu [1-$((i-1))]: " PROJECT_NUM

            # Walidacja wyboru
            if [[ "$PROJECT_NUM" =~ ^[0-9]+$ ]] && [ "$PROJECT_NUM" -ge 1 ] && [ "$PROJECT_NUM" -lt "$i" ]; then
                PROJECT_REF="${PROJECT_IDS[$((PROJECT_NUM-1))]}"
                echo "   Wybrany projekt: ${PROJECT_NAMES[$((PROJECT_NUM-1))]}"
            else
                echo "❌ Nieprawidłowy wybór"
                exit 1
            fi

            echo ""
            echo "🔑 Pobieram klucze API..."
            API_KEYS=$(curl -s -H "Authorization: Bearer $SUPABASE_TOKEN" "https://api.supabase.com/v1/projects/$PROJECT_REF/api-keys")

            SUPABASE_URL="https://${PROJECT_REF}.supabase.co"

            # Parsuj klucze API
            if command -v jq &>/dev/null; then
                SUPABASE_ANON_KEY=$(echo "$API_KEYS" | jq -r '.[] | select(.name == "anon") | .api_key')
                SUPABASE_SERVICE_KEY=$(echo "$API_KEYS" | jq -r '.[] | select(.name == "service_role") | .api_key')
            else
                SUPABASE_ANON_KEY=$(echo "$API_KEYS" | grep -o '"anon"[^}]*"api_key":"[^"]*"' | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
                SUPABASE_SERVICE_KEY=$(echo "$API_KEYS" | grep -o '"service_role"[^}]*"api_key":"[^"]*"' | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
            fi

            if [ -n "$SUPABASE_ANON_KEY" ] && [ -n "$SUPABASE_SERVICE_KEY" ]; then
                echo "✅ Klucze Supabase pobrane!"
                EXTRA_ENV="$EXTRA_ENV SUPABASE_URL='$SUPABASE_URL' SUPABASE_ANON_KEY='$SUPABASE_ANON_KEY' SUPABASE_SERVICE_KEY='$SUPABASE_SERVICE_KEY'"
            else
                echo "❌ Nie udało się pobrać kluczy API"
                exit 1
            fi
        else
            echo "❌ Nie udało się pobrać projektów: $PROJECTS"
            exit 1
        fi
    fi
    echo ""
fi

# =============================================================================
# TURNSTILE (dla GateFlow + Cloudflare) - PRZED instalacją
# =============================================================================

if [ "$APP_NAME" = "gateflow" ] && [ "$DOMAIN_TYPE" = "cloudflare" ] && [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo ""
    echo "🔒 Konfiguracja Turnstile (CAPTCHA)..."

    if [ -f "$REPO_ROOT/local/setup-turnstile.sh" ]; then
        if [ "$YES_MODE" = true ]; then
            # W trybie --yes sprawdź czy mamy zapisany token
            TURNSTILE_TOKEN_FILE="$HOME/.config/cloudflare/turnstile_token"
            if [ -f "$TURNSTILE_TOKEN_FILE" ]; then
                echo "   Automatyczna konfiguracja Turnstile..."
                # TODO: dodać --yes do setup-turnstile.sh
            fi
            echo -e "${YELLOW}⚠️  Tryb automatyczny: Turnstile wymaga interakcji.${NC}"
            echo "   Uruchom po instalacji: ./local/setup-turnstile.sh $DOMAIN $SSH_ALIAS"
        else
            # Tryb interaktywny - zapytaj
            echo ""
            read -p "Skonfigurować Turnstile teraz? [T/n]: " SETUP_TURNSTILE
            if [[ ! "$SETUP_TURNSTILE" =~ ^[Nn]$ ]]; then
                # Uruchom setup-turnstile interaktywnie
                "$REPO_ROOT/local/setup-turnstile.sh" "$DOMAIN"

                # Czytaj klucze z zapisanego pliku
                KEYS_FILE="$HOME/.config/cloudflare/turnstile_keys_$DOMAIN"
                if [ -f "$KEYS_FILE" ]; then
                    source "$KEYS_FILE"
                    if [ -n "$CLOUDFLARE_TURNSTILE_SITE_KEY" ] && [ -n "$CLOUDFLARE_TURNSTILE_SECRET_KEY" ]; then
                        EXTRA_ENV="$EXTRA_ENV CLOUDFLARE_TURNSTILE_SITE_KEY='$CLOUDFLARE_TURNSTILE_SITE_KEY' CLOUDFLARE_TURNSTILE_SECRET_KEY='$CLOUDFLARE_TURNSTILE_SECRET_KEY'"
                        echo -e "${GREEN}✅ Klucze Turnstile zostaną przekazane do instalacji${NC}"
                    fi
                fi
            else
                echo ""
                echo "⏭️  Pominięto. Możesz skonfigurować później:"
                echo "   ./local/setup-turnstile.sh $DOMAIN $SSH_ALIAS"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Brak skryptu setup-turnstile.sh${NC}"
    fi
    echo ""
fi

REMOTE_SCRIPT="/tmp/mikrus-deploy-$$.sh"
scp -q "$SCRIPT_PATH" "$SSH_ALIAS:$REMOTE_SCRIPT"

if ssh -t "$SSH_ALIAS" "export DEPLOY_SSH_ALIAS='$SSH_ALIAS' SSH_ALIAS='$SSH_ALIAS' $PORT_ENV $DB_ENV_VARS $DOMAIN_ENV $EXTRA_ENV; bash '$REMOTE_SCRIPT'; EXIT_CODE=\$?; rm -f '$REMOTE_SCRIPT'; exit \$EXIT_CODE"; then
    echo ""
    echo -e "${GREEN}✅ Instalacja zakończona pomyślnie${NC}"
else
    echo ""
    echo -e "${RED}❌ Instalacja NIEUDANA! Sprawdź błędy powyżej.${NC}"
    exit 1
fi

# =============================================================================
# MIGRACJE SUPABASE (dla GateFlow)
# =============================================================================

if [ "$APP_NAME" = "gateflow" ]; then
    echo ""
    echo "🗄️  Migracje bazy danych..."

    # Sprawdź czy mamy DATABASE_URL
    if [ -z "$DATABASE_URL" ]; then
        # Sprawdź w zapisanej konfiguracji
        SUPABASE_CONFIG="$HOME/.config/gateflow/supabase.env"
        if [ -f "$SUPABASE_CONFIG" ]; then
            source "$SUPABASE_CONFIG"
        fi
    fi

    if [ -z "$DATABASE_URL" ]; then
        if [ "$YES_MODE" = true ]; then
            echo -e "${YELLOW}⚠️  Brak DATABASE_URL - pominięto migracje${NC}"
            echo "   Uruchom później: DATABASE_URL=... ./local/setup-supabase-migrations.sh $SSH_ALIAS"
        else
            echo ""
            echo "Potrzebuję Database URL do uruchomienia migracji."
            echo ""
            echo "Gdzie go znaleźć:"
            echo "   1. Otwórz: https://supabase.com/dashboard"
            echo "   2. Wybierz projekt → Settings → Database"
            echo "   3. Sekcja 'Connection string' → URI"
            echo ""
            read -p "Wklej Database URL (postgresql://...) lub Enter aby pominąć: " DATABASE_URL
        fi
    fi

    if [ -n "$DATABASE_URL" ]; then
        # Zapisz do konfiguracji na przyszłość
        SUPABASE_CONFIG="$HOME/.config/gateflow/supabase.env"
        if [ -f "$SUPABASE_CONFIG" ] && ! grep -q "DATABASE_URL" "$SUPABASE_CONFIG"; then
            echo "DATABASE_URL='$DATABASE_URL'" >> "$SUPABASE_CONFIG"
            chmod 600 "$SUPABASE_CONFIG"
        fi

        # Uruchom migracje
        if [ -f "$REPO_ROOT/local/setup-supabase-migrations.sh" ]; then
            DATABASE_URL="$DATABASE_URL" "$REPO_ROOT/local/setup-supabase-migrations.sh" "$SSH_ALIAS"
        else
            echo -e "${YELLOW}⚠️  Brak skryptu migracji${NC}"
        fi
    else
        echo ""
        echo "⏭️  Pominięto migracje. Uruchom później:"
        echo "   DATABASE_URL=... ./local/setup-supabase-migrations.sh $SSH_ALIAS"
    fi
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

# Konfiguracja DOMAIN_PUBLIC (dla FileBrowser i podobnych)
if [ -n "$DOMAIN_PUBLIC" ]; then
    echo ""
    echo "🌍 Konfiguruję domenę publiczną: $DOMAIN_PUBLIC"

    # Sprawdź typ domeny
    is_cytrus_domain() {
        case "$1" in
            *.byst.re|*.bieda.it|*.toadres.pl|*.tojest.dev|*.mikr.us|*.srv24.pl|*.vxm.pl) return 0 ;;
            *) return 1 ;;
        esac
    }

    # Pobierz port dla public (domyślnie 8096)
    PUBLIC_PORT=$(ssh "$SSH_ALIAS" "cat /tmp/app_public_port 2>/dev/null || echo 8096")

    if is_cytrus_domain "$DOMAIN_PUBLIC"; then
        # Cytrus: rejestruj domenę przez API
        echo "   🍊 Rejestruję w Cytrus na porcie $PUBLIC_PORT..."
        "$REPO_ROOT/local/cytrus-domain.sh" "$DOMAIN_PUBLIC" "$PUBLIC_PORT" "$SSH_ALIAS"
    else
        # Cloudflare: skonfiguruj DNS i Caddy file_server
        echo "   ☁️  Konfiguruję przez Cloudflare..."
        WEBROOT=$(ssh "$SSH_ALIAS" "cat /tmp/domain_public_webroot 2>/dev/null || echo /var/www/public")
        # DNS może już istnieć - to OK, kontynuujemy z Caddy
        "$REPO_ROOT/local/dns-add.sh" "$DOMAIN_PUBLIC" "$SSH_ALIAS" || echo "   DNS już skonfigurowany lub błąd - kontynuuję"
        # Konfiguruj Caddy file_server
        if ssh "$SSH_ALIAS" "command -v mikrus-expose &>/dev/null && mikrus-expose '$DOMAIN_PUBLIC' '$WEBROOT' static"; then
            echo -e "   ${GREEN}✅ Static hosting skonfigurowany: https://$DOMAIN_PUBLIC${NC}"
        else
            echo -e "   ${YELLOW}⚠️  Nie udało się skonfigurować Caddy dla $DOMAIN_PUBLIC${NC}"
        fi
        # Cleanup
        ssh "$SSH_ALIAS" "rm -f /tmp/domain_public_webroot" 2>/dev/null
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

# Sugestia backupu dla aplikacji z bazą danych
if [ "$NEEDS_DB" = true ]; then
    echo ""
    echo -e "${YELLOW}💾 WAŻNE: Twoje dane są przechowywane w bazie danych!${NC}"
    echo "   Jeśli nie masz skonfigurowanego backupu bazy, rozważ:"
    echo ""
    echo "   Konfiguracja automatycznego backupu:"
    echo -e "      ${BLUE}ssh $SSH_ALIAS \"bash /opt/mikrus-toolbox/system/setup-db-backup.sh\"${NC}"
    echo ""
fi

echo ""
