#!/bin/bash

# Mikrus Toolbox - Vaultwarden
# Lightweight Bitwarden server written in Rust.
# Secure password management for your business.
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=330  # vaultwarden/server:latest
#
# Opcjonalne zmienne środowiskowe:
#   DOMAIN - domena dla Vaultwarden

set -e

APP_NAME="vaultwarden"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8088}

echo "--- 🔐 Vaultwarden Setup ---"
echo "NOTE: Once installed, create your account immediately."
echo "Then, restart the container with SIGNUPS_ALLOWED=false to secure it."
echo ""

# Domain
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "✅ Domena: $DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "✅ Domena: automatyczna (Cytrus)"
else
    echo "⚠️  Brak domeny - używam localhost"
fi

# Admin panel (interaktywnie, domyslnie wylaczony)
ADMIN_TOKEN_LINE=""
if [ -z "$YES" ] && [ -t 0 ]; then
    echo ""
    read -p "🔐 Włączyć panel admina /admin? (N/t): " ENABLE_ADMIN
    if [[ "$ENABLE_ADMIN" =~ ^[tTyY]$ ]]; then
        # Generuj token
        PLAIN_TOKEN=$(openssl rand -hex 32)

        # Hashuj Argon2 (instaluj jesli brak)
        if ! command -v argon2 &>/dev/null; then
            echo "📦 Instaluję argon2..."
            sudo apt-get install -y argon2 > /dev/null 2>&1 || { echo "⚠️  Nie udało się zainstalować argon2, zapisuję token plain text"; }
        fi

        if command -v argon2 &>/dev/null; then
            HASHED_TOKEN=$(echo -n "$PLAIN_TOKEN" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
            ADMIN_TOKEN_LINE="      - ADMIN_TOKEN=$HASHED_TOKEN"
        else
            ADMIN_TOKEN_LINE="      - ADMIN_TOKEN=$PLAIN_TOKEN"
        fi

        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  ZAPISZ TEN TOKEN — NIE DA SIĘ GO ODZYSKAĆ!            ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  $PLAIN_TOKEN  ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  Użyj go do logowania na /admin. W docker-compose zapisany jest"
        echo "  tylko hash (Argon2) — oryginał musisz zachować sam (np. w Vaultwarden)."
        echo ""
        read -p "  Naciśnij Enter gdy zapiszesz token..." _
    fi
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Set domain URL
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    DOMAIN_URL="https://$DOMAIN"
else
    DOMAIN_URL="http://localhost:$PORT"
fi

cat <<'COMPOSE' | sudo tee docker-compose.yaml > /dev/null
services:
  vaultwarden:
    image: vaultwarden/server:latest
    restart: always
    ports:
      - "PORT_PLACEHOLDER:80"
    environment:
      - DOMAIN=DOMAIN_PLACEHOLDER
      - SIGNUPS_ALLOWED=true
      - WEBSOCKET_ENABLED=true
      # --- Admin panel ---
      # Zeby wlaczyc recznie:
      #   1. Wygeneruj token:        openssl rand -hex 32
      #   2. Zahashuj (Argon2):       echo -n "TWOJ_TOKEN" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
      #   3. Odkomentuj i wklej hash: (jesli brak argon2: apt install argon2)
      #   4. Restart:                 docker compose up -d
      #   5. Loguj sie oryginalnym tokenem (nie hashem) na /admin
      #   6. Po zakonczeniu pracy zakomentuj ADMIN_TOKEN i zrestartuj
      #- ADMIN_TOKEN=$argon2id$v=19$m=65540,t=3,p=4$SALT$HASH
ADMIN_TOKEN_PLACEHOLDER
    volumes:
      - ./data:/data
    deploy:
      resources:
        limits:
          memory: 128M
COMPOSE

# Podmien placeholdery (sed, bo heredoc z <<'COMPOSE' nie interpoluje zmiennych)
sudo sed -i "s|PORT_PLACEHOLDER|$PORT|" docker-compose.yaml
sudo sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN_URL|" docker-compose.yaml

# Admin token: wstaw aktywna linie lub usun placeholder
if [ -n "$ADMIN_TOKEN_LINE" ]; then
    sudo sed -i "s|ADMIN_TOKEN_PLACEHOLDER|$ADMIN_TOKEN_LINE|" docker-compose.yaml
else
    sudo sed -i "/ADMIN_TOKEN_PLACEHOLDER/d" docker-compose.yaml
fi

sudo docker compose up -d

# Health check
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 30 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ Vaultwarden działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

# Caddy/HTTPS - only for real domains
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ] && [[ "$DOMAIN" != *"pending"* ]] && [[ "$DOMAIN" != *"cytrus"* ]]; then
    if command -v mikrus-expose &> /dev/null; then
        sudo mikrus-expose "$DOMAIN" "$PORT"
    fi
fi

echo ""
echo "✅ Vaultwarden started!"
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "🔗 Open https://$DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "🔗 Domena zostanie skonfigurowana automatycznie po instalacji"
else
    echo "🔗 Access via SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo ""
if [ -n "$ADMIN_TOKEN_LINE" ]; then
    echo "🔐 Admin panel WŁĄCZONY na /admin (token Argon2 w docker-compose)"
else
    echo "🔒 Admin panel WYŁĄCZONY (domyślnie)."
    echo "   Instrukcja włączenia: $STACK_DIR/docker-compose.yaml (komentarze w pliku)"
fi
echo ""
echo "📝 Następne kroki:"
echo "   1. Utwórz konto w przeglądarce"
echo "   2. Wyłącz rejestrację (komenda poniżej!)"
echo ""
echo "🔒 WAŻNE — wyłącz rejestrację po utworzeniu konta:"
echo "   ssh ${SSH_ALIAS:-mikrus} 'cd $STACK_DIR && sed -i \"s/SIGNUPS_ALLOWED=true/SIGNUPS_ALLOWED=false/\" docker-compose.yaml && docker compose up -d'"
