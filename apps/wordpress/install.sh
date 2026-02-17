#!/bin/bash

# Mikrus Toolbox - WordPress (Performance Edition)
# The world's most popular CMS. Blog, shop, portfolio - anything.
# https://wordpress.org
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=550  # wordpress:fpm-alpine+redis (~250MB) + nginx:alpine (~40MB) + redis:alpine (~30MB)
#
# Stack wydajnościowy:
#   wordpress:php8.3-fpm-alpine (PHP-FPM, nie Apache)
#   + nginx:alpine (static files, gzip, FastCGI cache)
#   + OPcache + JIT (2-3x szybszy PHP)
#   + FPM ondemand (dynamiczny tuning na podstawie RAM)
#   + Security headers + hardening
#
# Dwa tryby bazy danych:
#   1. MySQL (domyślny) - zewnętrzny MySQL z Mikrusa lub własny
#      deploy.sh automatycznie wykrywa potrzebę MySQL i pyta o dane
#   2. SQLite - WP_DB_MODE=sqlite, zero konfiguracji DB
#      Idealny dla prostych blogów na Mikrus 2.1
#
# Zmienne środowiskowe:
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS - z deploy.sh (tryb MySQL)
#   WP_DB_MODE - "mysql" (domyślne) lub "sqlite"
#   DOMAIN - domena (opcjonalne)
#   WP_REDIS (opcjonalne): auto|external|bundled (domyślnie: auto)
#   REDIS_PASS (opcjonalne): hasło do external Redis

set -e

APP_NAME="wordpress"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8080}

echo "--- 📝 WordPress Setup (Performance Edition) ---"
echo ""

WP_DB_MODE="${WP_DB_MODE:-mysql}"

# =============================================================================
# 1. DETEKCJA RAM → TUNING PHP-FPM
# =============================================================================

TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "1024")

if [ "$TOTAL_RAM" -ge 2000 ]; then
    FPM_MAX_CHILDREN=15
    WP_MEMORY="256M"
    NGINX_MEMORY="64M"
    echo "✅ RAM: ${TOTAL_RAM}MB → profil: duży (FPM: 15 workerów)"
elif [ "$TOTAL_RAM" -ge 1000 ]; then
    FPM_MAX_CHILDREN=8
    WP_MEMORY="256M"
    NGINX_MEMORY="48M"
    echo "✅ RAM: ${TOTAL_RAM}MB → profil: średni (FPM: 8 workerów)"
else
    FPM_MAX_CHILDREN=4
    WP_MEMORY="192M"
    NGINX_MEMORY="32M"
    echo "✅ RAM: ${TOTAL_RAM}MB → profil: lekki (FPM: 4 workery)"
fi

# =============================================================================
# 1a. DETEKCJA REDIS (external vs bundled)
# =============================================================================
# WP_REDIS=external  → użyj istniejącego na hoście (localhost:6379)
# WP_REDIS=bundled   → zawsze bundluj redis:alpine w compose
# WP_REDIS=auto      → auto-detekcja (domyślne)

source /opt/mikrus-toolbox/lib/redis-detect.sh 2>/dev/null || true
if type detect_redis &>/dev/null; then
    detect_redis "${WP_REDIS:-auto}" "redis"
else
    # Fallback jeśli lib niedostępne
    REDIS_HOST="redis"
    echo "✅ Redis: bundled (lib/redis-detect.sh niedostępne)"
fi

# Hasło Redis (user podaje przez REDIS_PASS env var)
REDIS_PASS="${REDIS_PASS:-}"
if [ -n "$REDIS_PASS" ] && [ "$REDIS_HOST" = "host-gateway" ]; then
    echo "   🔑 Hasło Redis: ustawione"
fi

# Domain
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "✅ Domena: $DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "✅ Domena: automatyczna (Cytrus)"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
fi

# Port binding: Cytrus wymaga 0.0.0.0, Cloudflare/local → 127.0.0.1 (bezpieczniejsze)
if [ "${DOMAIN_TYPE:-}" = "cytrus" ]; then
    BIND_ADDR=""
else
    BIND_ADDR="127.0.0.1:"
fi

# =============================================================================
# 2. WALIDACJA BAZY DANYCH
# =============================================================================

if [ "$WP_DB_MODE" = "sqlite" ]; then
    echo "✅ Tryb: WordPress + SQLite (lekki, bez MySQL)"
else
    echo "✅ Tryb: WordPress + MySQL"
    if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        echo "❌ Brak danych MySQL!"
        echo "   Wymagane: DB_HOST, DB_USER, DB_PASS, DB_NAME"
        echo ""
        echo "   Użyj deploy.sh - automatycznie skonfiguruje bazę:"
        echo "   ./local/deploy.sh wordpress --ssh=mikrus"
        echo ""
        echo "   Lub tryb SQLite (bez MySQL):"
        echo "   WP_DB_MODE=sqlite ./local/deploy.sh wordpress --ssh=mikrus"
        exit 1
    fi
    DB_PORT=${DB_PORT:-3306}
    DB_NAME=${DB_NAME:-wordpress}
    echo "   Host: $DB_HOST:$DB_PORT | User: $DB_USER | DB: $DB_NAME"

    # Sprawdź czy baza ma istniejące tabele WordPress
    _db_query() {
        if command -v mysql &>/dev/null; then
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" -sN 2>/dev/null
        elif command -v mariadb &>/dev/null; then
            mariadb -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" -sN 2>/dev/null
        elif command -v docker &>/dev/null; then
            docker run --rm mariadb:lts mariadb --skip-ssl -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" -sN 2>/dev/null
        else
            return 1
        fi
    }

    WP_TABLE_COUNT=$(_db_query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name LIKE 'wp_%'") || true
    if [ -n "$WP_TABLE_COUNT" ] && [ "$WP_TABLE_COUNT" -gt 0 ]; then
        echo ""
        echo "⚠️  Baza danych '$DB_NAME' zawiera $WP_TABLE_COUNT tabel WordPress!"
        echo "   WordPress podłączy się do istniejących danych (stary site)."
        echo "   Kreator instalacji NIE pojawi się — załaduje się stara strona."
        echo ""
        if [ -t 0 ] && [ "$YES_MODE" != true ]; then
            read -p "Kontynuować z istniejącą bazą? [t/N]: " DB_CONFIRM
            if [[ ! "$DB_CONFIRM" =~ ^[Tt]$ ]]; then
                echo "Anulowano."
                echo "   Aby wyczyścić bazę: zaloguj się do panelu (https://mikr.us/panel/),"
                echo "   a stamtąd do bazy danych i usuń tabele wp_*."
                echo "   Jeśli nie wiesz jak — zapytaj agenta AI, pomoże Ci krok po kroku."
                exit 1
            fi
        else
            echo "   ℹ️  Tryb --yes: kontynuuję (istniejące dane zostaną zachowane)"
        fi
    fi
fi
echo ""

# =============================================================================
# 3. PRZYGOTOWANIE KATALOGÓW
# =============================================================================

sudo mkdir -p "$STACK_DIR"/{config,wp-content,nginx-cache,redis-data}
cd "$STACK_DIR"

# Zapisz Redis config dla wp-init.sh
echo "$REDIS_HOST" | sudo tee "$STACK_DIR/.redis-host" > /dev/null
if [ -n "$REDIS_PASS" ]; then
    echo "$REDIS_PASS" | sudo tee "$STACK_DIR/.redis-pass" > /dev/null
    sudo chmod 600 "$STACK_DIR/.redis-pass"
fi

# =============================================================================
# 3a. DOCKERFILE (wordpress + redis extension + WP-CLI)
# =============================================================================

echo "⚙️  Generuję Dockerfile (PHP redis extension + WP-CLI)..."

cat <<'DOCKERFILE_EOF' | sudo tee "$STACK_DIR/Dockerfile" > /dev/null
FROM wordpress:php8.3-fpm-alpine

# PHP redis extension (dla Redis Object Cache)
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# WP-CLI (zarządzanie WordPress z konsoli)
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp
DOCKERFILE_EOF

# SQLite: pobierz plugin
if [ "$WP_DB_MODE" = "sqlite" ]; then
    sudo mkdir -p "$STACK_DIR/wp-content/database"
    echo "📥 Pobieram plugin WordPress SQLite Database Integration..."
    SQLITE_PLUGIN_URL="https://github.com/WordPress/sqlite-database-integration/archive/refs/heads/main.zip"
    TEMP_ZIP=$(mktemp)
    if curl -fsSL "$SQLITE_PLUGIN_URL" -o "$TEMP_ZIP"; then
        sudo mkdir -p "$STACK_DIR/wp-content/mu-plugins"
        sudo unzip -qo "$TEMP_ZIP" -d "$STACK_DIR/wp-content/mu-plugins/"
        sudo mv "$STACK_DIR/wp-content/mu-plugins/sqlite-database-integration-main" \
                "$STACK_DIR/wp-content/mu-plugins/sqlite-database-integration" 2>/dev/null || true
        sudo cp "$STACK_DIR/wp-content/mu-plugins/sqlite-database-integration/db.copy" \
                "$STACK_DIR/wp-content/db.php"
        echo "✅ Plugin SQLite zainstalowany"
    else
        echo "❌ Nie udało się pobrać pluginu SQLite"
        rm -f "$TEMP_ZIP"
        exit 1
    fi
    rm -f "$TEMP_ZIP"
fi

# =============================================================================
# 4. KONFIGURACJA PHP - OPcache + JIT + Security
# =============================================================================

echo "⚙️  Generuję konfigurację PHP (OPcache + JIT + security)..."

cat <<'OPCACHE_EOF' | sudo tee "$STACK_DIR/config/php-opcache.ini" > /dev/null
[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=0
opcache.validate_timestamps=0
opcache.fast_shutdown=1
opcache.max_wasted_percentage=10
opcache.jit=1255
opcache.jit_buffer_size=64M
OPCACHE_EOF

cat <<'PHPINI_EOF' | sudo tee "$STACK_DIR/config/php-performance.ini" > /dev/null
[PHP]
memory_limit = 256M
max_execution_time = 30
max_input_time = 60
post_max_size = 64M
upload_max_filesize = 64M
expose_php = Off
display_errors = Off
log_errors = On
error_log = /dev/stderr

; Compression (na poziomie PHP, Nginx też kompresuje)
zlib.output_compression = On
zlib.output_compression_level = 4

; Realpath cache - WordPress ma głęboką strukturę plików
; Domyślne 16k to za mało → 4096k eliminuje tysiące stat() per request
realpath_cache_size = 4096k
realpath_cache_ttl = 600

; Session security
session.cookie_secure = On
session.cookie_httponly = On
session.cookie_samesite = Lax
PHPINI_EOF

# =============================================================================
# 5. KONFIGURACJA PHP-FPM (ondemand, tuning na RAM)
# =============================================================================

echo "⚙️  Generuję konfigurację PHP-FPM (ondemand, max_children=$FPM_MAX_CHILDREN)..."

cat <<FPM_EOF | sudo tee "$STACK_DIR/config/www.conf" > /dev/null
[www]
user = www-data
group = www-data
listen = 9000

pm = ondemand
pm.max_children = $FPM_MAX_CHILDREN
pm.process_idle_timeout = 10s
pm.max_requests = 500

request_slowlog_timeout = 10s
slowlog = /proc/self/fd/2
FPM_EOF

# =============================================================================
# 6. KONFIGURACJA NGINX (static files, gzip, FastCGI cache, security headers)
# =============================================================================

echo "⚙️  Generuję konfigurację Nginx (gzip, FastCGI cache, security headers)..."

cat <<'NGINX_EOF' | sudo tee "$STACK_DIR/config/nginx.conf" > /dev/null
worker_processes auto;
worker_rlimit_nofile 8192;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    client_max_body_size 64M;
    server_tokens off;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_types
        text/plain
        text/css
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/xml
        image/svg+xml
        font/woff2;

    # Open file cache - zmniejsza disk I/O o ~80% dla static files
    open_file_cache max=10000 inactive=5m;
    open_file_cache_valid 2m;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    # FastCGI cache (24h dla stron, skip admin/login/API)
    fastcgi_cache_path /var/cache/nginx levels=1:2
        keys_zone=wordpress:10m max_size=256m inactive=24h;
    fastcgi_cache_key "$scheme$request_method$host$request_uri";
    fastcgi_cache_use_stale error timeout updating http_500 http_503;
    fastcgi_cache_lock on;
    fastcgi_cache_lock_timeout 5s;
    fastcgi_cache_background_update on;

    # Rate limiting - ochrona przed brute force (bez obciążania PHP)
    limit_req_zone $binary_remote_addr zone=wp_login:10m rate=1r/s;

    server {
        listen 80;
        server_name _;
        root /var/www/html;
        index index.php;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

        # Static files - cache 1 year, serwowane bez PHP
        location ~* \.(jpg|jpeg|png|gif|ico|webp|avif|css|js|svg|woff|woff2|ttf|eot)$ {
            expires 365d;
            add_header Cache-Control "public, immutable";
            access_log off;
        }

        # wp-login.php - rate limiting (1 req/s, burst 3)
        location = /wp-login.php {
            limit_req zone=wp_login burst=3 nodelay;
            limit_req_status 429;

            fastcgi_pass wordpress:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            fastcgi_param HTTPS $http_x_forwarded_proto if_not_empty;
        }

        # Blokuj xmlrpc.php - wektor DDoS i brute force, mało kto używa
        location = /xmlrpc.php {
            deny all;
            access_log off;
            log_not_found off;
        }

        # Blokuj user enumeration (?author=N)
        if ($args ~* "author=\d+") {
            return 403;
        }

        # Skip cache rules
        set $skip_cache 0;

        # Admin, login, API, cron - zawsze świeże
        if ($request_uri ~* "/wp-admin/|/wp-login\.php|/wp-json/|wp-.*\.php") {
            set $skip_cache 1;
        }

        # Zalogowani użytkownicy - zawsze świeże
        if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_logged_in") {
            set $skip_cache 1;
        }

        # POST requests - nie cachuj
        if ($request_method = POST) {
            set $skip_cache 1;
        }

        # PHP via FastCGI + cache
        location ~ \.php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass wordpress:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;

            # Przekaż info o HTTPS (dla reverse proxy fix)
            fastcgi_param HTTPS $http_x_forwarded_proto if_not_empty;

            # FastCGI buffers - optymalne dla WordPress responses
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
            fastcgi_keep_conn on;

            # FastCGI cache
            fastcgi_cache wordpress;
            fastcgi_cache_valid 200 24h;
            fastcgi_cache_bypass $skip_cache;
            fastcgi_no_cache $skip_cache;
            add_header X-FastCGI-Cache $upstream_cache_status;
        }

        location / {
            try_files $uri $uri/ /index.php?$args;
        }

        # Blokuj dostęp do wrażliwych plików
        location ~ /\.(ht|git|env) { deny all; }
        location = /wp-config.php { deny all; }
        location ~* /(?:uploads|files)/.*\.php$ { deny all; }
    }
}
NGINX_EOF

# =============================================================================
# 7. DOCKER-COMPOSE (FPM + Nginx)
# =============================================================================

echo "⚙️  Generuję docker-compose.yaml..."

# --- WordPress service (wspólna baza) ---
WP_ENV_BLOCK=""
if [ "$WP_DB_MODE" != "sqlite" ]; then
    WP_ENV_BLOCK="    environment:
      - WORDPRESS_DB_HOST=${DB_HOST}:${DB_PORT}
      - WORDPRESS_DB_USER=${DB_USER}
      - WORDPRESS_DB_PASSWORD=${DB_PASS}
      - WORDPRESS_DB_NAME=${DB_NAME}"
fi

# --- Redis: bundled vs external ---
WP_DEPENDS=""
WP_EXTRA_HOSTS=""
REDIS_SERVICE=""

if [ "$REDIS_HOST" = "redis" ]; then
    # Bundled Redis
    WP_DEPENDS="    depends_on:
      - redis"
    REDIS_SERVICE="
  redis:
    image: redis:alpine
    restart: always
    command: redis-server --maxmemory 64mb --maxmemory-policy allkeys-lru --save 60 1 --loglevel warning
    volumes:
      - ./redis-data:/data
    security_opt:
      - no-new-privileges:true
    logging:
      driver: json-file
      options:
        max-size: \"5m\"
        max-file: \"2\"
    healthcheck:
      test: [\"CMD\", \"redis-cli\", \"ping\"]
      interval: 10s
      timeout: 3s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 96M"
else
    # External Redis - łącz z hostem
    WP_EXTRA_HOSTS="    extra_hosts:
      - \"host-gateway:host-gateway\""
fi

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  wordpress:
    build: .
    restart: always
$WP_ENV_BLOCK
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./config/php-opcache.ini:/usr/local/etc/php/conf.d/opcache.ini:ro
      - ./config/php-performance.ini:/usr/local/etc/php/conf.d/performance.ini:ro
      - ./config/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
      - wp-html:/var/www/html
    tmpfs:
      - /tmp:size=128M,mode=1777
$WP_DEPENDS
$WP_EXTRA_HOSTS
    security_opt:
      - no-new-privileges:true
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD-SHELL", "php -v > /dev/null"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: $WP_MEMORY
$REDIS_SERVICE

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "${BIND_ADDR}$PORT:80"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - /dev/null:/etc/nginx/conf.d/default.conf:ro
      - ./nginx-cache:/var/cache/nginx
      - wp-html:/var/www/html:ro
      - ./wp-content:/var/www/html/wp-content:ro
    depends_on:
      - wordpress
    security_opt:
      - no-new-privileges:true
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "wget", "-qO/dev/null", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: $NGINX_MEMORY

volumes:
  wp-html:
EOF

# Wyczyść puste linie z YAML (z pustych bloków warunkowych)
sudo sed -i '/^$/{ N; /^\n$/d; }' docker-compose.yaml

# =============================================================================
# 8. WP-INIT.SH (post-install: HTTPS fix, wp-cron, performance defines)
# =============================================================================

cat <<'INITEOF' | sudo tee "$STACK_DIR/wp-init.sh" > /dev/null
#!/bin/bash
# WordPress Performance Init — automatycznie uruchamiany przez install.sh
# Idempotentny — bezpieczne ponowne uruchomienie
# Generuje wp-config-performance.php + dodaje require_once do wp-config.php
# Redis Object Cache plugin via WP-CLI

cd "$(dirname "$0")"

QUIET=false
RETRY_MODE=false
RETRY_COUNT_FILE="/opt/stacks/wordpress/.wp-init-retries"
MAX_RETRIES=30

if [ "$1" = "--retry" ]; then
    QUIET=true
    RETRY_MODE=true
    # Licznik prób — usuń crona po MAX_RETRIES (30 min)
    COUNT=0
    [ -f "$RETRY_COUNT_FILE" ] && COUNT=$(cat "$RETRY_COUNT_FILE")
    COUNT=$((COUNT + 1))
    echo "$COUNT" > "$RETRY_COUNT_FILE"
    if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
        crontab -l 2>/dev/null | grep -v "wp-init-retry" | crontab -
        rm -f "$RETRY_COUNT_FILE"
        exit 0
    fi
fi

log() { [ "$QUIET" = false ] && echo "$@"; }

WP_CONFIG="/var/www/html/wp-config.php"
PERF_CONFIG="/var/www/html/wp-config-performance.php"
CONTAINER=$(docker compose ps -q wordpress 2>/dev/null | head -1)

if [ -z "$CONTAINER" ]; then
    log "❌ Kontener WordPress nie działa"
    exit 1
fi

# --- Część 1: wp-config-performance.php (nie wymaga tabel w DB) ---

if ! docker exec "$CONTAINER" test -f "$WP_CONFIG"; then
    log "⏳ WordPress jeszcze nie wygenerował wp-config.php"
    log "   Otwórz stronę w przeglądarce, a optymalizacje zastosują się automatycznie."
    if ! crontab -l 2>/dev/null | grep -q "wp-init-retry"; then
        RETRY="* * * * * /opt/stacks/wordpress/wp-init.sh --retry > /dev/null 2>&1 # wp-init-retry"
        (crontab -l 2>/dev/null; echo "$RETRY") | crontab -
        log "   ⏰ Retry co minutę aż wp-config.php będzie gotowy"
    fi
    exit 0
fi

log "🔧 Optymalizuję wp-config.php..."

# Redis config
REDIS_HOST="redis"
if [ -f "/opt/stacks/wordpress/.redis-host" ]; then
    REDIS_HOST=$(cat /opt/stacks/wordpress/.redis-host)
fi
REDIS_PASS=""
if [ -f "/opt/stacks/wordpress/.redis-pass" ]; then
    REDIS_PASS=$(cat /opt/stacks/wordpress/.redis-pass)
fi
if [ "$REDIS_HOST" = "host-gateway" ]; then
    WP_REDIS_ADDR="host-gateway"
else
    WP_REDIS_ADDR="$REDIS_HOST"
fi

REDIS_PASS_LINE=""
if [ -n "$REDIS_PASS" ]; then
    REDIS_PASS_LINE="define('WP_REDIS_PASSWORD', '$REDIS_PASS');"
fi

# Generuj wp-config-performance.php (zawsze nadpisuje — idempotentne)
cat <<PERFEOF | docker exec -i "$CONTAINER" tee "$PERF_CONFIG" > /dev/null
<?php
// Mikrus Toolbox — WordPress Performance Config
// Wygenerowane przez wp-init.sh — NIE edytuj ręcznie

// HTTPS behind reverse proxy (Cytrus/Caddy/Cloudflare)
if (isset(\$_SERVER["HTTP_X_FORWARDED_PROTO"]) && \$_SERVER["HTTP_X_FORWARDED_PROTO"] === "https") {
    \$_SERVER["HTTPS"] = "on";
}

// Performance & Security
define('DISABLE_WP_CRON', true);
define('WP_POST_REVISIONS', 5);
define('EMPTY_TRASH_DAYS', 14);
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');
define('AUTOSAVE_INTERVAL', 300);
define('DISALLOW_FILE_EDIT', true);

// Redis Object Cache
define('WP_REDIS_HOST', '$WP_REDIS_ADDR');
define('WP_REDIS_PORT', 6379);
${REDIS_PASS_LINE}
define('WP_CACHE', true);
PERFEOF

docker exec "$CONTAINER" chown www-data:www-data "$PERF_CONFIG"
log "   ✅ Wygenerowano wp-config-performance.php"

# Dodaj require_once do wp-config.php (jednorazowo)
if ! docker exec "$CONTAINER" grep -q "wp-config-performance.php" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i '/^<?php/a\require_once __DIR__ . "/wp-config-performance.php";' "$WP_CONFIG"
    log "   ✅ Dodano require_once do wp-config.php"
else
    log "   ℹ️  require_once już istnieje w wp-config.php"
fi

# --- Część 2: WP-CLI (wymaga tabel w DB — może nie zadziałać od razu) ---

REDIS_OK=false
if docker exec "$CONTAINER" test -f /usr/local/bin/wp; then
    # Sprawdź czy DB jest gotowa (tabele istnieją)
    if docker exec -u www-data "$CONTAINER" wp db check --path=/var/www/html > /dev/null 2>&1; then
        if ! docker exec -u www-data "$CONTAINER" wp plugin is-installed redis-cache --path=/var/www/html 2>/dev/null; then
            log "   📥 Instaluję plugin Redis Object Cache..."
            if docker exec -u www-data "$CONTAINER" wp plugin install redis-cache --activate --path=/var/www/html 2>/dev/null; then
                log "   ✅ Plugin Redis Object Cache zainstalowany i aktywowany"
                REDIS_OK=true
            fi
        else
            docker exec -u www-data "$CONTAINER" wp plugin activate redis-cache --path=/var/www/html 2>/dev/null || true
            REDIS_OK=true
            log "   ℹ️  Plugin Redis Object Cache już zainstalowany"
        fi

        if [ "$REDIS_OK" = true ]; then
            docker exec -u www-data "$CONTAINER" wp redis enable --path=/var/www/html --force 2>/dev/null \
                && log "   ✅ Redis Object Cache włączony (drop-in aktywny)" \
                || log "   ⚠️  Nie udało się włączyć Redis drop-in"
        fi
    else
        log "   ℹ️  Baza danych jeszcze nie zainicjalizowana — Redis plugin zostanie zainstalowany automatycznie"
    fi
fi

# Dodaj retry cron jeśli Redis plugin nie został zainstalowany
if [ "$REDIS_OK" = false ] && ! crontab -l 2>/dev/null | grep -q "wp-init-retry"; then
    RETRY="* * * * * /opt/stacks/wordpress/wp-init.sh --retry > /dev/null 2>&1 # wp-init-retry"
    (crontab -l 2>/dev/null; echo "$RETRY") | crontab -
    log "   ⏰ Redis plugin — retry co minutę aż baza będzie gotowa"
fi

# Usuń retry cron jeśli Redis OK
if [ "$REDIS_OK" = true ] && crontab -l 2>/dev/null | grep -q "wp-init-retry"; then
    crontab -l 2>/dev/null | grep -v "wp-init-retry" | crontab -
    rm -f "$RETRY_COUNT_FILE"
    log "   ✅ Retry cron usunięty (Redis działa)"
fi

# --- Część 3: Systemowy cron i cache ---

CRON_CMD="*/5 * * * * docker exec \$(docker compose -f /opt/stacks/wordpress/docker-compose.yaml ps -q wordpress) php /var/www/html/wp-cron.php > /dev/null 2>&1"
if ! crontab -l 2>/dev/null | grep -q "wp-cron.php"; then
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    log "   ✅ Systemowy cron dodany (co 5 min)"
else
    log "   ℹ️  Systemowy cron już istnieje"
fi

if [ -d "/opt/stacks/wordpress/nginx-cache" ]; then
    rm -rf /opt/stacks/wordpress/nginx-cache/*
    log "   ✅ FastCGI cache wyczyszczony"
fi

log ""
log "✅ Wszystkie optymalizacje zastosowane!"
INITEOF
sudo chmod +x "$STACK_DIR/wp-init.sh"

# Skrypt do czyszczenia cache (przydatne po aktualizacji treści)
cat <<'CACHEEOF' | sudo tee "$STACK_DIR/flush-cache.sh" > /dev/null
#!/bin/bash
# Wyczyść FastCGI cache Nginx (po aktualizacji treści/wtyczek)
rm -rf /opt/stacks/wordpress/nginx-cache/*
docker compose -f /opt/stacks/wordpress/docker-compose.yaml exec nginx nginx -s reload 2>/dev/null || true
echo "✅ FastCGI cache wyczyszczony"
CACHEEOF
sudo chmod +x "$STACK_DIR/flush-cache.sh"

# =============================================================================
# 9. URUCHOMIENIE
# =============================================================================

# Uprawnienia dla wp-content (www-data = UID 82 w alpine, 33 w debian)
# wordpress:fpm-alpine używa UID 82
sudo chown -R 82:82 "$STACK_DIR/wp-content"

echo ""
echo "🔨 Buduję obraz WordPress (redis extension + WP-CLI)..."
sudo docker compose build --quiet 2>/dev/null || sudo docker compose build

echo "🚀 Uruchamiam WordPress (FPM + Nginx + Redis)..."
sudo docker compose up -d

# Health check - build + start potrzebują więcej czasu
echo "⏳ Czekam na uruchomienie..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 60 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    for i in $(seq 1 6); do
        sleep 10
        if curl -sf "http://localhost:$PORT" > /dev/null 2>&1; then
            echo "✅ WordPress działa (po $((i*10))s)"
            break
        fi
        echo "   ... $((i*10))s"
        if [ "$i" -eq 6 ]; then
            echo "❌ Nie wystartował w 60s!"
            sudo docker compose logs --tail 30
            exit 1
        fi
    done
fi

# =============================================================================
# 9a. AUTOMATYCZNE OPTYMALIZACJE (wp-init.sh)
# =============================================================================

echo ""
echo "⚙️  Uruchamiam optymalizacje wp-config.php..."
bash "$STACK_DIR/wp-init.sh" 2>&1 | sed 's/^/   /'

# =============================================================================
# 10. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ WordPress zainstalowany! (Performance Edition)"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "🔗 Otwórz https://$DOMAIN aby dokończyć instalację"
elif [ "$DOMAIN" = "-" ]; then
    echo "🔗 Domena zostanie skonfigurowana automatycznie po instalacji"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi

echo ""
echo "📝 Następny krok:"
echo "   Otwórz stronę w przeglądarce → kreator instalacji WordPress"
echo ""

echo "⚡ Co zostało zoptymalizowane automatycznie:"
echo "   • PHP-FPM alpine (lżejszy niż Apache)"
echo "   • OPcache + JIT (2-3x szybszy PHP)"
echo "   • Redis Object Cache (-70% zapytań do DB)"
echo "   • Nginx FastCGI cache (cache wygasa po 24h)"
echo "   • Gzip compression (-60-80% bandwidth)"
echo "   • Security headers + rate limiting + xmlrpc block"
echo "   • FPM ondemand ($FPM_MAX_CHILDREN workerów, tuning na ${TOTAL_RAM}MB RAM)"
echo "   • HTTPS reverse proxy fix"
echo "   • Systemowy cron (zamiast wp-cron, co 5 min)"
echo "   • Limity rewizji, pamięci, autosave"
echo ""

echo "📋 Przydatne komendy (na serwerze, w $STACK_DIR):"
echo "   ./flush-cache.sh       — wyczyść cache Nginx (po zmianach treści/wtyczek)"
echo "   docker compose logs -f — logi (FPM + Nginx + Redis)"
echo ""

echo "   Tryb bazy: $WP_DB_MODE"
if [ "$WP_DB_MODE" = "sqlite" ]; then
    echo "   Baza: SQLite w wp-content/database/"
else
    echo "   Baza: MySQL ($DB_HOST:$DB_PORT/$DB_NAME)"
fi
