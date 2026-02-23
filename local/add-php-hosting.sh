#!/bin/bash

# Mikrus Toolbox - Add PHP Hosting
# Dodaje hosting stron PHP.
# Cytrus: Docker (Caddy + PHP-FPM) na wysokim porcie.
# Cloudflare: natywny Caddy + PHP-FPM na hoście.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/add-php-hosting.sh DOMENA [SSH_ALIAS] [KATALOG] [PORT]
#
# Przykłady:
#   ./local/add-php-hosting.sh mysite.byst.re
#   ./local/add-php-hosting.sh mysite.byst.re mikrus /var/www/mysite 8090
#   ./local/add-php-hosting.sh app.example.com mikrus /var/www/app

set -e

DOMAIN="$1"
SSH_ALIAS="${2:-mikrus}"
WEB_ROOT="${3:-/var/www/php}"
PORT="${4:-8090}"

if [ -z "$DOMAIN" ]; then
    echo "Użycie: $0 DOMENA [SSH_ALIAS] [KATALOG] [PORT]"
    echo ""
    echo "Przykłady:"
    echo "  $0 mysite.byst.re                              # Cytrus, domyślne ustawienia"
    echo "  $0 app.example.com mikrus                       # Cloudflare"
    echo "  $0 mysite.byst.re mikrus /var/www/mysite 8090  # Własny katalog i port"
    echo ""
    echo "Domyślne:"
    echo "  SSH_ALIAS: mikrus"
    echo "  KATALOG:   /var/www/php"
    echo "  PORT:      8090 (tylko Cytrus)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/server-exec.sh"

echo ""
echo "🐘 Dodawanie PHP Hosting"
echo ""
echo "   Domena:  $DOMAIN"
echo "   Serwer:  $SSH_ALIAS"
echo "   Katalog: $WEB_ROOT"
echo ""

# Wykryj typ domeny
is_cytrus_domain() {
    case "$1" in
        *.byst.re|*.bieda.it|*.toadres.pl|*.tojest.dev|*.mikr.us|*.srv24.pl|*.vxm.pl|*.cytr.us) return 0 ;;
        *) return 1 ;;
    esac
}

# Czekaj aż port odpowiada (kluczowe dla Cytrus — domena musi być dodana PO uruchomieniu usługi)
wait_for_port() {
    local PORT=$1
    local MAX=5
    echo "⏳ Czekam na uruchomienie usługi na porcie $PORT..."
    for i in $(seq 1 $MAX); do
        sleep 3
        if server_exec "curl -sf -o /dev/null http://localhost:$PORT/ 2>/dev/null"; then
            echo "✅ Port $PORT odpowiada"
            return 0
        fi
        echo "   Próba $i/$MAX..."
    done
    echo "⚠️  Port $PORT nie odpowiada po $MAX próbach"
    return 1
}

if is_cytrus_domain "$DOMAIN"; then
    echo "🍊 Tryb: Cytrus (Docker: Caddy + PHP-FPM)"
    echo "   Port: $PORT"
    echo ""

    # Utwórz katalog na pliki PHP
    server_exec "sudo mkdir -p '$WEB_ROOT' && sudo chown -R \$(whoami) '$WEB_ROOT'"

    # Sprawdź czy port wolny
    if server_exec "ss -tlnp 2>/dev/null | grep -q ':$PORT '"; then
        echo "❌ Port $PORT jest już zajęty!"
        echo "   Użyj innego portu: $0 $DOMAIN $SSH_ALIAS $WEB_ROOT INNY_PORT"
        exit 1
    fi

    # Stwórz stack Docker z Caddy + PHP-FPM
    STACK_NAME="php-$(echo "$DOMAIN" | sed 's/\./-/g')"
    server_exec "mkdir -p /opt/stacks/$STACK_NAME && cat > /opt/stacks/$STACK_NAME/Caddyfile << 'CADDYEOF'
:80 {
    root * /var/www/html
    php_fastcgi php:9000
    file_server
}
CADDYEOF

cat > /opt/stacks/$STACK_NAME/docker-compose.yaml << COMPOSEEOF
services:
  php:
    image: php:8.3-fpm-alpine
    restart: always
    volumes:
      - $WEB_ROOT:/var/www/html:ro
    deploy:
      resources:
        limits:
          memory: 128M

  caddy:
    image: caddy:alpine
    restart: always
    ports:
      - \"$PORT:80\"
    volumes:
      - /opt/stacks/$STACK_NAME/Caddyfile:/etc/caddy/Caddyfile:ro
      - $WEB_ROOT:/var/www/html:ro
    depends_on:
      - php
    deploy:
      resources:
        limits:
          memory: 64M
COMPOSEEOF

cd /opt/stacks/$STACK_NAME && docker compose pull -q 2>/dev/null; docker compose up -d" || { echo "❌ Docker start failed"; exit 1; }

    echo "✅ Kontenery uruchomione"

    # Czekaj aż port odpowiada — kluczowe!
    wait_for_port "$PORT" || echo "⚠️  Kontynuuję mimo braku odpowiedzi..."

    # TERAZ rejestruj domenę (po potwierdzeniu że usługa działa)
    echo ""
    "$SCRIPT_DIR/cytrus-domain.sh" "$DOMAIN" "$PORT" "$SSH_ALIAS"

else
    echo "☁️  Tryb: Cloudflare (natywny Caddy + PHP-FPM)"
    echo ""

    # Utwórz katalog
    server_exec "sudo mkdir -p '$WEB_ROOT' && sudo chown -R \$(whoami) '$WEB_ROOT' && sudo chmod -R o+rX '$WEB_ROOT'"

    # Zainstaluj PHP-FPM jeśli brak
    if ! server_exec "ls /run/php/php*-fpm.sock >/dev/null 2>&1"; then
        echo "📦 Instaluję PHP-FPM..."
        server_exec "bash -c '
            PHP_VER=\$(php -r \"echo PHP_MAJOR_VERSION . \\\".\\\" . PHP_MINOR_VERSION;\" 2>/dev/null || echo \"\")
            if [ -z \"\$PHP_VER\" ]; then
                sudo apt-get update -qq && sudo apt-get install -y -qq php-fpm 2>&1
            else
                sudo apt-get update -qq && sudo apt-get install -y -qq php\${PHP_VER}-fpm 2>&1
            fi
            PHP_SVC=\$(systemctl list-unit-files | grep php.*fpm | awk \"{print \\\$1}\" | head -1)
            if [ -n \"\$PHP_SVC\" ]; then
                sudo systemctl enable \"\$PHP_SVC\"
                sudo systemctl start \"\$PHP_SVC\"
            fi
        '" || echo "⚠️  PHP-FPM instalacja — sprawdź ręcznie"
        echo "✅ PHP-FPM zainstalowany"
    else
        echo "✅ PHP-FPM już zainstalowany"
    fi

    # Zainstaluj Caddy jeśli brak
    if ! server_exec "command -v mikrus-expose >/dev/null 2>&1"; then
        echo "📦 Instaluję Caddy + mikrus-expose..."
        server_exec "bash -s" < "$SCRIPT_DIR/../system/caddy-install.sh" || { echo "❌ Caddy install failed"; exit 1; }
        echo "✅ Caddy zainstalowany"
    else
        echo "✅ Caddy już zainstalowany"
    fi

    # Skonfiguruj DNS
    "$SCRIPT_DIR/dns-add.sh" "$DOMAIN" "$SSH_ALIAS" || echo "DNS może już istnieć"

    # Skonfiguruj Caddy z PHP-FPM
    server_exec "mikrus-expose '$DOMAIN' '$WEB_ROOT' php"

    echo "✅ Caddy + PHP-FPM skonfigurowany"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ PHP Hosting gotowy!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🌍 URL: https://$DOMAIN"
echo "📂 Pliki: $WEB_ROOT"
echo ""
echo "Test:     ssh $SSH_ALIAS \"echo '<?php echo phpinfo();' > $WEB_ROOT/info.php\""
echo "Sprawdź:  curl https://$DOMAIN/info.php"
echo ""
