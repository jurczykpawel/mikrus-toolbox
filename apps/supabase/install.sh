#!/bin/bash

# Mikrus Toolbox - Supabase Self-Hosted
# Open-source Firebase alternative: PostgreSQL, Auth, Storage, Realtime, Functions, Studio.
# https://supabase.com/docs/guides/self-hosting/docker
#
# IMAGE_SIZE_MB=4000  # ~10 kontenerów: studio, kong, auth, rest, realtime, storage,
#                       imgproxy, meta, analytics, db, vector, supavisor
#
# ⚠️  WYMAGA: Minimum 2GB RAM (Mikrus 3.0+)
#     Zalecane: 3GB+ RAM
#     Supabase uruchamia ~10 kontenerów serwisowych.
#
# Opcjonalne zmienne środowiskowe (przekazywane przez deploy.sh lub ustawiane ręcznie):
#   PORT              - Port Kong API + Studio (domyślnie: 8000)
#   POSTGRES_PASSWORD - Hasło PostgreSQL (generowane automatycznie)
#   JWT_SECRET        - Sekret JWT (generowany automatycznie)
#   DASHBOARD_PASSWORD - Hasło dashboardu (generowane automatycznie)
#   SITE_URL          - URL strony dla Auth redirects (domyślnie: SUPABASE_PUBLIC_URL)

set -e

APP_NAME="supabase"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8000}

echo "--- 🔥 Supabase Self-Hosted Setup ---"
echo "Open-source Firebase alternative: PostgreSQL, Auth, Storage, Realtime, Functions."
echo ""

# =============================================================================
# 1. PRE-FLIGHT CHECKS
# =============================================================================

# RAM check
TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo 0)

if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 1800 ]; then
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ Za mało RAM! Supabase wymaga minimum 2GB RAM.             ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    printf "║  Twój serwer: %-4s MB RAM                                   ║\n" "$TOTAL_RAM"
    echo "║  Wymagane:    2048 MB (minimum)                               ║"
    echo "║  Zalecane:    3072 MB (Mikrus 3.0+)                          ║"
    echo "║                                                                ║"
    echo "║  Supabase uruchamia ~10 kontenerów Docker.                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 2800 ]; then
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  Supabase zaleca 3GB RAM (Mikrus 3.0+)                  ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    printf "║  Twój serwer: %-4s MB RAM                                   ║\n" "$TOTAL_RAM"
    echo "║  Na 2GB działa, ale może zostać mało RAM dla innych apek.    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
fi

# Disk check
FREE_DISK=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
if [ "$FREE_DISK" -gt 0 ] && [ "$FREE_DISK" -lt 3000 ]; then
    echo "❌ Za mało miejsca na dysku! Wymagane: 3GB, dostępne: ${FREE_DISK}MB (~$((FREE_DISK / 1024))GB)"
    exit 1
fi

echo "✅ RAM: ${TOTAL_RAM}MB | Dysk: ${FREE_DISK}MB wolne"

# Port check for PostgreSQL pooler
POOLER_HOST_PORT=5432
if ss -tlnp 2>/dev/null | grep -q ":5432 " || netstat -tlnp 2>/dev/null | grep -q ":5432 "; then
    POOLER_HOST_PORT=5433
    echo "⚠️  Port 5432 zajęty — pooler PostgreSQL będzie dostępny na porcie hosta 5433"
fi
echo ""

# =============================================================================
# 2. GENERUJ SEKRETY
# Uses the same approach as the official generate-keys.sh
# =============================================================================

echo "🔐 Generuję sekrety..."

# JWT helper (pure openssl - no python/node needed)
base64_url_encode() {
    openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

gen_jwt() {
    local secret="$1"
    local role="$2"
    local header='{"alg":"HS256","typ":"JWT"}'
    local iat exp payload header_b64 payload_b64 signed sig
    iat=$(date +%s)
    exp=$((iat + 5 * 3600 * 24 * 365))
    payload="{\"role\":\"${role}\",\"iss\":\"supabase\",\"iat\":${iat},\"exp\":${exp}}"
    header_b64=$(printf '%s' "$header" | base64_url_encode)
    payload_b64=$(printf '%s' "$payload" | base64_url_encode)
    signed="${header_b64}.${payload_b64}"
    sig=$(printf '%s' "$signed" | openssl dgst -binary -sha256 -hmac "$secret" | base64_url_encode)
    printf '%s' "${signed}.${sig}"
}

# Preserve credentials from existing install to avoid password mismatch with existing DB volumes.
# The Supabase postgres image blocks ALTER USER supabase_admin via SQL (reserved role),
# so if volumes exist from a previous run, they must use the same POSTGRES_PASSWORD.
if [ -f "$STACK_DIR/.env" ]; then
    POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(sudo grep '^POSTGRES_PASSWORD=' "$STACK_DIR/.env" 2>/dev/null | cut -d= -f2)}"
    JWT_SECRET="${JWT_SECRET:-$(sudo grep '^JWT_SECRET=' "$STACK_DIR/.env" 2>/dev/null | cut -d= -f2)}"
    DASHBOARD_PASSWORD="${DASHBOARD_PASSWORD:-$(sudo grep '^DASHBOARD_PASSWORD=' "$STACK_DIR/.env" 2>/dev/null | cut -d= -f2)}"
    echo "   ℹ️  Istniejące dane logowania zachowane (reinstalacja)"
fi

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 16)}"
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 30)}"
SECRET_KEY_BASE=$(openssl rand -base64 48)
VAULT_ENC_KEY=$(openssl rand -hex 16)
PG_META_CRYPTO_KEY=$(openssl rand -base64 24)
LOGFLARE_PUBLIC_TOKEN=$(openssl rand -base64 24)
LOGFLARE_PRIVATE_TOKEN=$(openssl rand -base64 24)
S3_ACCESS_KEY=$(openssl rand -hex 16)
S3_SECRET_KEY=$(openssl rand -hex 32)
MINIO_ROOT_PASSWORD=$(openssl rand -hex 16)
POOLER_TENANT_ID=$(openssl rand -hex 8)
DASHBOARD_PASSWORD="${DASHBOARD_PASSWORD:-$(openssl rand -hex 16)}"

echo "   Generuję klucze JWT..."
ANON_KEY=$(gen_jwt "$JWT_SECRET" "anon")
SERVICE_ROLE_KEY=$(gen_jwt "$JWT_SECRET" "service_role")

echo "✅ Sekrety wygenerowane"

# =============================================================================
# 3. POBIERZ OFICJALNY DOCKER SETUP Z GITHUB
# =============================================================================

echo ""
echo "📥 Pobieram oficjalny Supabase Docker..."
sudo mkdir -p "$STACK_DIR"

if [ -f "$STACK_DIR/docker-compose.yml" ]; then
    echo "✅ Docker setup już istnieje (pomijam pobieranie)"
else
    if ! command -v git &>/dev/null; then
        echo "❌ git nie znaleziony! Zainstaluj: apt-get install -y git"
        exit 1
    fi

    TMP_DIR=$(mktemp -d)
    echo "   Klonuję repozytorium Supabase (tylko katalog docker/)..."

    git clone \
        --filter=blob:none \
        --no-checkout \
        --depth 1 \
        --quiet \
        https://github.com/supabase/supabase.git "$TMP_DIR"

    cd "$TMP_DIR"
    git sparse-checkout init --cone 2>/dev/null || git sparse-checkout init
    git sparse-checkout set docker
    git checkout --quiet HEAD

    sudo cp -r docker/. "$STACK_DIR/"
    cd /
    rm -rf "$TMP_DIR"

    echo "✅ Docker setup pobrany z GitHub"
fi

cd "$STACK_DIR"

# =============================================================================
# 4. KONFIGURUJ .env
# =============================================================================

echo ""
echo "⚙️  Konfiguruję .env..."

sudo cp .env.example .env

# URL configuration
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    SUPABASE_PUBLIC_URL="https://$DOMAIN"
else
    SUPABASE_PUBLIC_URL="http://localhost:$PORT"
fi
SITE_URL="${SITE_URL:-$SUPABASE_PUBLIC_URL}"

# Apply all settings
sudo sed -i \
    -e "s|^POSTGRES_PASSWORD=.*$|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
    -e "s|^JWT_SECRET=.*$|JWT_SECRET=${JWT_SECRET}|" \
    -e "s|^ANON_KEY=.*$|ANON_KEY=${ANON_KEY}|" \
    -e "s|^SERVICE_ROLE_KEY=.*$|SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}|" \
    -e "s|^SECRET_KEY_BASE=.*$|SECRET_KEY_BASE=${SECRET_KEY_BASE}|" \
    -e "s|^VAULT_ENC_KEY=.*$|VAULT_ENC_KEY=${VAULT_ENC_KEY}|" \
    -e "s|^PG_META_CRYPTO_KEY=.*$|PG_META_CRYPTO_KEY=${PG_META_CRYPTO_KEY}|" \
    -e "s|^LOGFLARE_PUBLIC_ACCESS_TOKEN=.*$|LOGFLARE_PUBLIC_ACCESS_TOKEN=${LOGFLARE_PUBLIC_TOKEN}|" \
    -e "s|^LOGFLARE_PRIVATE_ACCESS_TOKEN=.*$|LOGFLARE_PRIVATE_ACCESS_TOKEN=${LOGFLARE_PRIVATE_TOKEN}|" \
    -e "s|^S3_PROTOCOL_ACCESS_KEY_ID=.*$|S3_PROTOCOL_ACCESS_KEY_ID=${S3_ACCESS_KEY}|" \
    -e "s|^S3_PROTOCOL_ACCESS_KEY_SECRET=.*$|S3_PROTOCOL_ACCESS_KEY_SECRET=${S3_SECRET_KEY}|" \
    -e "s|^MINIO_ROOT_PASSWORD=.*$|MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}|" \
    -e "s|^DASHBOARD_PASSWORD=.*$|DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}|" \
    -e "s|^SUPABASE_PUBLIC_URL=.*$|SUPABASE_PUBLIC_URL=${SUPABASE_PUBLIC_URL}|" \
    -e "s|^API_EXTERNAL_URL=.*$|API_EXTERNAL_URL=${SUPABASE_PUBLIC_URL}|" \
    -e "s|^SITE_URL=.*$|SITE_URL=${SITE_URL}|" \
    -e "s|^POOLER_TENANT_ID=.*$|POOLER_TENANT_ID=${POOLER_TENANT_ID}|" \
    -e "s|^KONG_HTTP_PORT=.*$|KONG_HTTP_PORT=${PORT}|" \
    -e "s|^KONG_HTTPS_PORT=.*$|KONG_HTTPS_PORT=$((PORT + 443))|" \
    .env

# Patch pooler host port in docker-compose.yml if 5432 is taken on host.
# POSTGRES_PORT stays 5432 for internal Docker network; only the host binding changes.
if [ "$POOLER_HOST_PORT" != "5432" ]; then
    sudo sed -i "s|- \${POSTGRES_PORT}:5432|- ${POOLER_HOST_PORT}:5432|" docker-compose.yml
fi

sudo chmod 600 .env
echo "✅ Konfiguracja gotowa"

# =============================================================================
# 5. URUCHOM SUPABASE
# =============================================================================

echo ""
echo "🚀 Pobieram obrazy Docker i uruchamiam Supabase..."
echo "   (Pierwsze uruchomienie: 5-15 minut, pobieranie ~3-4GB obrazów)"
echo ""

sudo docker compose pull

# Start db + vector first — analytics has a race condition on fresh DB init.
# The DB health check passes before init scripts finish, causing analytics to time out.
echo "   Uruchamiam bazę danych (inicjalizacja może potrwać do 5 min)..."
sudo docker compose up -d db vector

# Wait for DB init scripts to finish.
# The postgres role is created by migrate.sh during container init — it does NOT exist before
# migrate.sh runs (supabase_admin is in the image base, but postgres is created later).
# We connect via 127.0.0.1 (trust auth) as supabase_admin to avoid chicken-and-egg with peer auth.
DB_INIT_DONE=0
for i in $(seq 1 60); do
    if sudo docker exec supabase-db psql -U supabase_admin -h 127.0.0.1 -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='postgres'" 2>/dev/null | grep -q 1; then
        DB_INIT_DONE=1
        break
    fi
    printf "."
    sleep 5
done
echo ""

if [ "$DB_INIT_DONE" -ne 1 ]; then
    echo "⚠️  Inicjalizacja bazy trwa dłużej niż oczekiwano — kontynuuję"
fi

echo "   Uruchamiam wszystkie serwisy..."
sudo docker compose up -d --wait --wait-timeout 300 || true

# =============================================================================
# 6. HEALTH CHECK
# =============================================================================

echo ""
echo "⏳ Czekam na uruchomienie API (max 2.5 min)..."

SUPABASE_UP=0
for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/rest/v1/" \
        -H "apikey: $ANON_KEY" \
        -H "Authorization: Bearer $ANON_KEY" > /dev/null 2>&1; then
        SUPABASE_UP=1
        break
    fi
    printf "."
    sleep 5
done
echo ""

if [ "$SUPABASE_UP" -eq 1 ]; then
    echo "✅ API działa!"
else
    echo "⏳ API jeszcze się uruchamia. Status kontenerów:"
    sudo docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null \
        || sudo docker compose ps
    echo ""
    echo "   Sprawdź logi: cd $STACK_DIR && sudo docker compose logs -f"
fi

# HTTPS via Caddy (for real domains only)
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ] && [[ "$DOMAIN" != *"pending"* ]] && [[ "$DOMAIN" != *"PENDING"* ]]; then
    echo "--- Konfiguruję HTTPS via Caddy ---"
    if command -v mikrus-expose &>/dev/null; then
        sudo mikrus-expose "$DOMAIN" "$PORT"
    else
        echo "⚠️  'mikrus-expose' nie znalezione. Skonfiguruj reverse proxy ręcznie."
    fi
fi

# =============================================================================
# 7. ZAPISZ KONFIGURACJĘ
# =============================================================================

CONFIG_DIR="$HOME/.config/supabase"
CONFIG_FILE="$CONFIG_DIR/deploy-config.env"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<CONF
# Supabase Self-Hosted - Konfiguracja
# Wygenerowano: $(date)

SUPABASE_URL=$SUPABASE_PUBLIC_URL
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
CONF

chmod 600 "$CONFIG_FILE"

# =============================================================================
# 8. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "✅ Supabase zainstalowany pomyślnie!"
echo "════════════════════════════════════════════════════════════════════"
echo ""

if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "🔗 Studio + API:  https://$DOMAIN"
else
    echo "🔗 Studio + API:  http://localhost:$PORT"
    echo ""
    echo "   SSH tunnel (z komputera):"
    echo "   ssh -L $PORT:localhost:$PORT <serwer>"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "🔑 KONFIGURACJA — ZAPISZ TE DANE W BEZPIECZNYM MIEJSCU!"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Supabase URL:          $SUPABASE_PUBLIC_URL"
echo "  Anon Key (publiczny):  $ANON_KEY"
echo "  Service Key (sekret):  $SERVICE_ROLE_KEY"
echo ""
echo "  Dashboard login:       supabase"
echo "  Dashboard hasło:       $DASHBOARD_PASSWORD"
echo ""
echo "  PostgreSQL hasło:      $POSTGRES_PASSWORD"
echo ""
echo "  Konfiguracja zapisana: $CONFIG_FILE"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️  WAŻNE: Skonfiguruj SMTP przed produkcją!                 ║"
echo "║     Edytuj: $STACK_DIR/.env → sekcja SMTP              ║"
echo "║     Domyślnie: Inbucket (fake SMTP, tylko do testów).         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Zarządzanie:"
echo "   cd $STACK_DIR"
echo "   sudo docker compose ps            # status kontenerów"
echo "   sudo docker compose logs -f       # logi wszystkich serwisów"
echo "   sudo docker compose logs -f db    # logi PostgreSQL"
echo "   sudo docker compose restart       # restart"
echo "   sudo docker compose down          # zatrzymaj"
echo ""
