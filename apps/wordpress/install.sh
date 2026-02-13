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

# Domain
if [ -n "$DOMAIN" ]; then
    echo "✅ Domena: $DOMAIN"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
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
        echo "   ./local/deploy.sh wordpress --ssh=hanna"
        echo ""
        echo "   Lub tryb SQLite (bez MySQL):"
        echo "   WP_DB_MODE=sqlite ./local/deploy.sh wordpress --ssh=hanna"
        exit 1
    fi
    DB_PORT=${DB_PORT:-3306}
    DB_NAME=${DB_NAME:-wordpress}
    echo "   Host: $DB_HOST:$DB_PORT | User: $DB_USER | DB: $DB_NAME"
fi
echo ""

# =============================================================================
# 3. PRZYGOTOWANIE KATALOGÓW
# =============================================================================

sudo mkdir -p "$STACK_DIR"/{config,wp-content,nginx-cache}
cd "$STACK_DIR"

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

if [ "$WP_DB_MODE" = "sqlite" ]; then
    # SQLite: bez zmiennych DB
    cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  wordpress:
    build: .
    restart: always
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./config/php-opcache.ini:/usr/local/etc/php/conf.d/opcache.ini:ro
      - ./config/php-performance.ini:/usr/local/etc/php/conf.d/performance.ini:ro
      - ./config/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
      - wp-html:/var/www/html
    tmpfs:
      - /tmp:size=128M,mode=1777
    depends_on:
      - redis
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
        max-size: "5m"
        max-file: "2"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 96M

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "127.0.0.1:$PORT:80"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
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
else
    # MySQL: ze zmiennymi DB
    cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  wordpress:
    build: .
    restart: always
    environment:
      - WORDPRESS_DB_HOST=${DB_HOST}:${DB_PORT}
      - WORDPRESS_DB_USER=${DB_USER}
      - WORDPRESS_DB_PASSWORD=${DB_PASS}
      - WORDPRESS_DB_NAME=${DB_NAME}
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./config/php-opcache.ini:/usr/local/etc/php/conf.d/opcache.ini:ro
      - ./config/php-performance.ini:/usr/local/etc/php/conf.d/performance.ini:ro
      - ./config/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
      - wp-html:/var/www/html
    tmpfs:
      - /tmp:size=128M,mode=1777
    depends_on:
      - redis
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
        max-size: "5m"
        max-file: "2"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 96M

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "127.0.0.1:$PORT:80"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
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
fi

# =============================================================================
# 8. WP-INIT.SH (post-install: HTTPS fix, wp-cron, performance defines)
# =============================================================================

cat <<'INITEOF' | sudo tee "$STACK_DIR/wp-init.sh" > /dev/null
#!/bin/bash
# WordPress Performance Init
# Uruchom po pierwszym starcie (gdy wp-config.php istnieje)
# Dodaje: HTTPS fix, WP-Cron, limity rewizji, memory limit

cd "$(dirname "$0")"

WP_CONFIG="/var/www/html/wp-config.php"
CONTAINER=$(docker compose ps -q wordpress 2>/dev/null | head -1)

if [ -z "$CONTAINER" ]; then
    echo "❌ Kontener WordPress nie działa"
    exit 1
fi

if ! docker exec "$CONTAINER" test -f "$WP_CONFIG"; then
    echo "⏳ WordPress jeszcze się nie zainicjalizował (brak wp-config.php)"
    echo "   Otwórz stronę w przeglądarce aby ukończyć instalację,"
    echo "   a potem uruchom ten skrypt ponownie."
    exit 0
fi

echo "🔧 Optymalizuję wp-config.php..."

# 1. Fix HTTPS za reverse proxy (Cytrus/Caddy/Cloudflare)
if ! docker exec "$CONTAINER" grep -q "HTTP_X_FORWARDED_PROTO" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i '/^<?php/a\
// HTTPS behind reverse proxy (Cytrus/Caddy/Cloudflare)\
if (isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) \&\& $_SERVER["HTTP_X_FORWARDED_PROTO"] === "https") {\
    $_SERVER["HTTPS"] = "on";\
}' "$WP_CONFIG"
    echo "   ✅ Fix HTTPS za reverse proxy"
fi

# 2. Wyłącz domyślny wp-cron
if ! docker exec "$CONTAINER" grep -q "DISABLE_WP_CRON" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('DISABLE_WP_CRON', true);" "$WP_CONFIG"
    echo "   ✅ WP-Cron wyłączony (systemowy cron co 5 min)"
fi

# 3. Limit rewizji (mniejsza baza)
if ! docker exec "$CONTAINER" grep -q "WP_POST_REVISIONS" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('WP_POST_REVISIONS', 5);" "$WP_CONFIG"
    echo "   ✅ Limit rewizji: 5 (mniejsza baza)"
fi

# 4. Auto-czyszczenie kosza
if ! docker exec "$CONTAINER" grep -q "EMPTY_TRASH_DAYS" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('EMPTY_TRASH_DAYS', 14);" "$WP_CONFIG"
    echo "   ✅ Auto-czyszczenie kosza: 14 dni"
fi

# 5. WordPress memory limit
if ! docker exec "$CONTAINER" grep -q "WP_MEMORY_LIMIT" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('WP_MEMORY_LIMIT', '256M');\
define('WP_MAX_MEMORY_LIMIT', '512M');" "$WP_CONFIG"
    echo "   ✅ WP Memory Limit: 256M (admin: 512M)"
fi

# 6. Zwiększ interwał autosave (mniej zapisów do DB)
if ! docker exec "$CONTAINER" grep -q "AUTOSAVE_INTERVAL" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('AUTOSAVE_INTERVAL', 300);" "$WP_CONFIG"
    echo "   ✅ Autosave: co 5 min (zamiast 60s)"
fi

# 7. Zablokuj edycję plików z panelu WP (security)
if ! docker exec "$CONTAINER" grep -q "DISALLOW_FILE_EDIT" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('DISALLOW_FILE_EDIT', true);" "$WP_CONFIG"
    echo "   ✅ Edycja plików z panelu WP zablokowana"
fi

# 8. Redis Object Cache - wp-config.php defines
if ! docker exec "$CONTAINER" grep -q "WP_REDIS_HOST" "$WP_CONFIG"; then
    docker exec "$CONTAINER" sed -i "/^<?php/a\\
define('WP_REDIS_HOST', 'redis');\
define('WP_REDIS_PORT', 6379);\
define('WP_CACHE', true);" "$WP_CONFIG"
    echo "   ✅ Redis config (WP_REDIS_HOST=redis, WP_CACHE=true)"
fi

# 9. Redis Object Cache - instalacja pluginu przez WP-CLI
if docker exec "$CONTAINER" test -f /usr/local/bin/wp; then
    if ! docker exec -u www-data "$CONTAINER" wp plugin is-installed redis-cache --path=/var/www/html 2>/dev/null; then
        echo "   📥 Instaluję plugin Redis Object Cache..."
        docker exec -u www-data "$CONTAINER" wp plugin install redis-cache --activate --path=/var/www/html 2>/dev/null
        echo "   ✅ Plugin Redis Object Cache zainstalowany i aktywowany"
    else
        docker exec -u www-data "$CONTAINER" wp plugin activate redis-cache --path=/var/www/html 2>/dev/null || true
        echo "   ℹ️  Plugin Redis Object Cache już zainstalowany"
    fi

    # Włącz object cache drop-in (kopiuje object-cache.php do wp-content/)
    docker exec -u www-data "$CONTAINER" wp redis enable --path=/var/www/html --force 2>/dev/null \
        && echo "   ✅ Redis Object Cache włączony (drop-in aktywny)" \
        || echo "   ⚠️  Nie udało się włączyć Redis drop-in (sprawdź: wp redis status)"
else
    echo "   ⚠️  WP-CLI niedostępny - zainstaluj plugin Redis Object Cache ręcznie"
fi

# 11. Dodaj systemowy cron automatycznie
CRON_CMD="*/5 * * * * docker exec \$(docker compose -f /opt/stacks/wordpress/docker-compose.yaml ps -q wordpress) php /var/www/html/wp-cron.php > /dev/null 2>&1"
if ! crontab -l 2>/dev/null | grep -q "wp-cron.php"; then
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "   ✅ Systemowy cron dodany (co 5 min)"
else
    echo "   ℹ️  Systemowy cron już istnieje"
fi

# 12. Flush FastCGI cache
if [ -d "/opt/stacks/wordpress/nginx-cache" ]; then
    rm -rf /opt/stacks/wordpress/nginx-cache/*
    echo "   ✅ FastCGI cache wyczyszczony"
fi

echo ""
echo "✅ Wszystkie optymalizacje zastosowane!"
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
# 10. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ WordPress zainstalowany! (Performance Edition)"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ -n "$DOMAIN" ]; then
    echo "🔗 Otwórz https://$DOMAIN aby dokończyć instalację"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi

echo ""
echo "📝 Następne kroki:"
echo "   1. Otwórz stronę → kreator instalacji WordPress"
echo "   2. Po instalacji uruchom optymalizacje:"
echo "      ssh \$SSH_ALIAS 'cd $STACK_DIR && ./wp-init.sh'"
echo ""

echo "⚡ Co jest zoptymalizowane automatycznie:"
echo "   • PHP-FPM alpine (lżejszy niż Apache)"
echo "   • OPcache + JIT (2-3x szybszy PHP)"
echo "   • Redis Object Cache (-70% zapytań do DB)"
echo "   • Nginx FastCGI cache (cached strony = 0ms PHP)"
echo "   • Gzip compression (-60-80% bandwidth)"
echo "   • Security headers + rate limiting + xmlrpc block"
echo "   • FPM ondemand ($FPM_MAX_CHILDREN workerów, tuning na ${TOTAL_RAM}MB RAM)"
echo ""

echo "📋 Przydatne komendy:"
echo "   ./flush-cache.sh          - wyczyść FastCGI cache"
echo "   ./wp-init.sh              - optymalizacje wp-config.php + Redis plugin"
echo "   docker compose logs -f    - logi (FPM + Nginx + Redis)"
echo ""

echo "   Tryb bazy: $WP_DB_MODE"
if [ "$WP_DB_MODE" = "sqlite" ]; then
    echo "   Baza: SQLite w wp-content/database/"
else
    echo "   Baza: MySQL ($DB_HOST:$DB_PORT/$DB_NAME)"
fi

echo ""
echo "💡 Dodatkowa optymalizacja (ręczna):"
echo "   • Converter for Media - wtyczka WP → automatyczny WebP"
