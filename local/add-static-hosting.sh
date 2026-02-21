#!/bin/bash

# Mikrus Toolbox - Add Static Hosting
# Dodaje publiczny hosting plików statycznych.
# Używa nginx w Dockerze dla Cytrus lub Caddy file_server dla Cloudflare.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/add-static-hosting.sh DOMENA [SSH_ALIAS] [KATALOG] [PORT]
#
# Przykłady:
#   ./local/add-static-hosting.sh static.byst.re
#   ./local/add-static-hosting.sh static.byst.re mikrus /var/www/public 8096
#   ./local/add-static-hosting.sh cdn.example.com mikrus /var/www/assets 8097

set -e

DOMAIN="$1"
SSH_ALIAS="${2:-mikrus}"
WEB_ROOT="${3:-/var/www/public}"
PORT="${4:-8096}"

if [ -z "$DOMAIN" ]; then
    echo "Użycie: $0 DOMENA [SSH_ALIAS] [KATALOG] [PORT]"
    echo ""
    echo "Przykłady:"
    echo "  $0 static.byst.re                              # Cytrus, domyślne ustawienia"
    echo "  $0 cdn.example.com mikrus                       # Cloudflare"
    echo "  $0 assets.byst.re mikrus /var/www/assets 8097  # Własny katalog i port"
    echo ""
    echo "Domyślne:"
    echo "  SSH_ALIAS: mikrus"
    echo "  KATALOG:   /var/www/public"
    echo "  PORT:      8096"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/server-exec.sh"

echo ""
echo "🌍 Dodawanie Static Hosting"
echo ""
echo "   Domena:  $DOMAIN"
echo "   Serwer:  $SSH_ALIAS"
echo "   Katalog: $WEB_ROOT"
echo "   Port:    $PORT"
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
    echo "🍊 Tryb: Cytrus (nginx w Dockerze)"

    # Utwórz katalog
    server_exec "sudo mkdir -p '$WEB_ROOT' && sudo chown -R \$(whoami) '$WEB_ROOT' && sudo chmod -R o+rX '$WEB_ROOT'"

    # Sprawdź czy port wolny
    if server_exec "netstat -tlnp 2>/dev/null | grep -q ':$PORT ' || ss -tlnp | grep -q ':$PORT '"; then
        echo "❌ Port $PORT jest już zajęty!"
        echo "   Użyj innego portu: $0 $DOMAIN $SSH_ALIAS $WEB_ROOT INNY_PORT"
        exit 1
    fi

    # Uruchom nginx
    STACK_NAME="static-$(echo "$DOMAIN" | sed 's/\./-/g')"
    server_exec "mkdir -p /opt/stacks/$STACK_NAME && cat > /opt/stacks/$STACK_NAME/docker-compose.yaml << 'EOF'
services:
  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - \"$PORT:80\"
    volumes:
      - $WEB_ROOT:/usr/share/nginx/html:ro
    deploy:
      resources:
        limits:
          memory: 32M
EOF
cd /opt/stacks/$STACK_NAME && docker compose up -d"

    echo "✅ nginx uruchomiony na porcie $PORT"

    # Czekaj aż port odpowiada — kluczowe!
    wait_for_port "$PORT" || echo "⚠️  Kontynuuję mimo braku odpowiedzi..."

    # TERAZ rejestruj domenę (po potwierdzeniu że usługa działa)
    echo ""
    "$SCRIPT_DIR/cytrus-domain.sh" "$DOMAIN" "$PORT" "$SSH_ALIAS"

else
    echo "☁️  Tryb: Cloudflare (Caddy file_server)"

    # Utwórz katalog
    server_exec "sudo mkdir -p '$WEB_ROOT' && sudo chown -R \$(whoami) '$WEB_ROOT' && sudo chmod -R o+rX '$WEB_ROOT'"

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

    # Skonfiguruj Caddy
    server_exec "mikrus-expose '$DOMAIN' '$WEB_ROOT' static"

    echo "✅ Caddy skonfigurowany"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Static Hosting gotowy!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🌍 URL: https://$DOMAIN"
echo "📂 Pliki: $WEB_ROOT"
echo ""
echo "Wrzuć plik: ssh $SSH_ALIAS 'echo test > $WEB_ROOT/test.txt'"
echo "Sprawdź:    curl https://$DOMAIN/test.txt"
echo ""
