#!/bin/bash

# Mikrus Toolbox - WordPress
# The world's most popular CMS. Blog, shop, portfolio - anything.
# https://wordpress.org
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=700  # wordpress:latest
#
# Dwa tryby bazy danych:
#   1. MySQL (domyślny) - zewnętrzny MySQL z Mikrusa lub własny
#      deploy.sh automatycznie wykrywa potrzebę MySQL i pyta o dane
#   2. SQLite - WP_DB_MODE=sqlite, zero konfiguracji DB
#      Idealny dla prostych blogów na Mikrus 1.0
#
# Zmienne środowiskowe:
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS - z deploy.sh (tryb MySQL)
#   WP_DB_MODE - "mysql" (domyślne) lub "sqlite"
#   DOMAIN - domena (opcjonalne)

set -e

APP_NAME="wordpress"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8080}

echo "--- 📝 WordPress Setup ---"
echo ""

WP_DB_MODE="${WP_DB_MODE:-mysql}"

# Domain
if [ -n "$DOMAIN" ]; then
    echo "✅ Domena: $DOMAIN"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# =============================================================================
# TRYB SQLite (lekki, bez bazy MySQL)
# =============================================================================

if [ "$WP_DB_MODE" = "sqlite" ]; then
    echo "✅ Tryb: WordPress + SQLite (lekki, bez MySQL)"
    echo ""

    # Przygotuj katalogi
    sudo mkdir -p "$STACK_DIR/wp-content/database"

    # Pobierz oficjalny plugin SQLite
    echo "📥 Pobieram plugin WordPress SQLite Database Integration..."
    SQLITE_PLUGIN_URL="https://github.com/WordPress/sqlite-database-integration/archive/refs/heads/main.zip"
    TEMP_ZIP=$(mktemp)
    if curl -fsSL "$SQLITE_PLUGIN_URL" -o "$TEMP_ZIP"; then
        sudo mkdir -p "$STACK_DIR/wp-content/mu-plugins"
        sudo unzip -qo "$TEMP_ZIP" -d "$STACK_DIR/wp-content/mu-plugins/"
        sudo mv "$STACK_DIR/wp-content/mu-plugins/sqlite-database-integration-main" \
                "$STACK_DIR/wp-content/mu-plugins/sqlite-database-integration"
        # Kopiuj db.php drop-in
        sudo cp "$STACK_DIR/wp-content/mu-plugins/sqlite-database-integration/db.copy" \
                "$STACK_DIR/wp-content/db.php"
        echo "✅ Plugin SQLite zainstalowany"
    else
        echo "❌ Nie udało się pobrać pluginu SQLite"
        echo "   Pobierz ręcznie: https://github.com/WordPress/sqlite-database-integration"
        rm -f "$TEMP_ZIP"
        exit 1
    fi
    rm -f "$TEMP_ZIP"

    # docker-compose bez MySQL
    cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "$PORT:80"
    volumes:
      - ./wp-content:/var/www/html/wp-content
    deploy:
      resources:
        limits:
          memory: 256M
EOF

# =============================================================================
# TRYB MySQL (domyślny - zewnętrzny MySQL z deploy.sh)
# =============================================================================

else
    echo "✅ Tryb: WordPress + MySQL"

    # Sprawdź dane bazy
    if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        echo "❌ Brak danych MySQL!"
        echo "   Wymagane: DB_HOST, DB_USER, DB_PASS, DB_NAME"
        echo ""
        echo "   Użyj deploy.sh - automatycznie skonfiguruje bazę:"
        echo "   ./local/deploy.sh wordpress --ssh=hanna"
        echo ""
        echo "   Lub tryb SQLite (bez MySQL):"
        echo "   WP_DB_MODE=sqlite ./local/deploy.sh wordpress --ssh=hanna"
        exit 1
    fi

    DB_PORT=${DB_PORT:-3306}
    DB_NAME=${DB_NAME:-wordpress}

    echo "   Host: $DB_HOST:$DB_PORT | User: $DB_USER | DB: $DB_NAME"
    echo ""

    # Przygotuj katalogi
    sudo mkdir -p "$STACK_DIR/wp-content"

    cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "$PORT:80"
    environment:
      - WORDPRESS_DB_HOST=${DB_HOST}:${DB_PORT}
      - WORDPRESS_DB_USER=${DB_USER}
      - WORDPRESS_DB_PASSWORD=${DB_PASS}
      - WORDPRESS_DB_NAME=${DB_NAME}
    volumes:
      - ./wp-content:/var/www/html/wp-content
    deploy:
      resources:
        limits:
          memory: 256M
EOF
fi

# =============================================================================
# HTTPS PROXY FIX + WP-CRON OPTIMIZATION
# =============================================================================

# Utwórz skrypt inicjalizacyjny który doda fix po pierwszym starcie WP
cat <<'INITEOF' | sudo tee "$STACK_DIR/wp-init.sh" > /dev/null
#!/bin/bash
# Dodaje fix HTTPS za reverse proxy + wyłącza domyślny wp-cron
# Uruchom po pierwszym starcie WordPressa (gdy wp-config.php już istnieje)

WP_CONFIG="/var/www/html/wp-config.php"
CONTAINER=$(docker compose ps -q wordpress 2>/dev/null | head -1)

if [ -z "$CONTAINER" ]; then
    echo "❌ Kontener WordPress nie działa"
    exit 1
fi

# Sprawdź czy wp-config.php istnieje
if ! docker exec "$CONTAINER" test -f "$WP_CONFIG"; then
    echo "⏳ WordPress jeszcze się nie zainicjalizował (brak wp-config.php)"
    echo "   Otwórz stronę w przeglądarce aby ukończyć instalację,"
    echo "   a potem uruchom ten skrypt ponownie."
    exit 0
fi

# Dodaj fix HTTPS za reverse proxy
if ! docker exec "$CONTAINER" grep -q "HTTP_X_FORWARDED_PROTO" "$WP_CONFIG"; then
    echo "🔧 Dodaję fix HTTPS za reverse proxy..."
    docker exec "$CONTAINER" sed -i '/^<?php/a\
// HTTPS behind reverse proxy (Cytrus/Caddy/Cloudflare)\
if (isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) \&\& $_SERVER["HTTP_X_FORWARDED_PROTO"] === "https") {\
    $_SERVER["HTTPS"] = "on";\
}' "$WP_CONFIG"
    echo "✅ Fix HTTPS dodany"
fi

# Wyłącz domyślny wp-cron (będzie przez systemowy cron)
if ! docker exec "$CONTAINER" grep -q "DISABLE_WP_CRON" "$WP_CONFIG"; then
    echo "🔧 Wyłączam domyślny WP-Cron..."
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
// Wyłącz domyślny wp-cron (uruchamiany przez systemowy cron co 5 min)\\
define('DISABLE_WP_CRON', true);" "$WP_CONFIG"
    echo "✅ WP-Cron wyłączony"
fi

echo ""
echo "✅ Konfiguracja WordPress zaktualizowana!"
echo ""
echo "Dodaj systemowy cron (zalecane):"
echo "   (crontab -l 2>/dev/null; echo '*/5 * * * * docker exec \$(docker compose -f /opt/stacks/wordpress/docker-compose.yaml ps -q wordpress) php /var/www/html/wp-cron.php > /dev/null 2>&1') | crontab -"
INITEOF
sudo chmod +x "$STACK_DIR/wp-init.sh"

# =============================================================================
# URUCHOMIENIE
# =============================================================================

# Uprawnienia dla wp-content (www-data = UID 33)
sudo chown -R 33:33 "$STACK_DIR/wp-content"

sudo docker compose up -d

# Health check - WordPress potrzebuje ~30-60s na inicjalizację
echo "⏳ Czekam na uruchomienie WordPress..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 60 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 10
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ WordPress działa na porcie $PORT"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

# =============================================================================
# PODSUMOWANIE
# =============================================================================

echo ""
if [ -n "$DOMAIN" ]; then
    echo "🔗 Otwórz https://$DOMAIN aby dokończyć instalację"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo ""
echo "📝 Następne kroki:"
echo "   1. Otwórz stronę - kreator instalacji WordPress"
echo "   2. Po instalacji uruchom fix HTTPS + wp-cron:"
echo "      ssh \$SSH_ALIAS 'cd $STACK_DIR && ./wp-init.sh'"

# Sprawdź czy Redis jest zainstalowany
if [ -d "/opt/stacks/redis" ] && sudo docker compose -f /opt/stacks/redis/docker-compose.yaml ps -q redis 2>/dev/null | head -1 | grep -q .; then
    echo ""
    echo "💡 Masz Redis na serwerze! Zainstaluj wtyczkę 'Redis Object Cache'"
    echo "   w panelu WordPress dla lepszej wydajności."
fi

echo ""
echo "   Tryb bazy: $WP_DB_MODE"
if [ "$WP_DB_MODE" = "sqlite" ]; then
    echo "   Baza: SQLite w wp-content/database/"
else
    echo "   Baza: MySQL ($DB_HOST:$DB_PORT/$DB_NAME)"
fi
