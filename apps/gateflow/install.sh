#!/bin/bash

# Mikrus Toolbox - GateFlow
# Self-hosted digital products sales platform (Gumroad/EasyCart alternative)
# Author: Paweł (Lazy Engineer)
#
# Wymagane:
#   - Mikrus 3.0+ (1GB RAM)
#   - Konto Supabase (darmowe)
#   - Konto Stripe
#
# Zmienne środowiskowe (opcjonalne - można podać interaktywnie):
#   STRIPE_PK          - Stripe Publishable Key
#   STRIPE_SK          - Stripe Secret Key
#   STRIPE_WEBHOOK_SECRET - Stripe Webhook Secret (opcjonalne)
#   DOMAIN             - Domena aplikacji

set -e

APP_NAME="gateflow"
INSTALL_DIR="/root/gateflow"
PORT=${PORT:-3333}
REPO_URL="${REPO_URL:-git@github.com:pavvel11/gateflow.git}"
BRANCH="${BRANCH:-dev}"

echo "--- 💰 GateFlow Setup ---"
echo ""

# =============================================================================
# 1. INSTALACJA BUN + PM2
# =============================================================================

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

if ! command -v bun &> /dev/null || ! command -v pm2 &> /dev/null; then
    echo "📦 Instaluję Bun + PM2..."
    if [ -f "/opt/mikrus-toolbox/system/bun-setup.sh" ]; then
        source /opt/mikrus-toolbox/system/bun-setup.sh
    else
        # Fallback - instaluj bezpośrednio
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
        bun install -g pm2
    fi
fi

echo "✅ Bun: v$(bun --version)"
echo "✅ PM2: v$(pm2 --version)"
echo ""

# =============================================================================
# 2. KLONOWANIE REPOZYTORIUM
# =============================================================================

echo "📥 Pobieram GateFlow..."

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "   Aktualizuję istniejącą instalację..."
    cd "$INSTALL_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
else
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    git checkout "$BRANCH"
fi

echo "✅ Kod źródłowy pobrany"
echo ""

# =============================================================================
# 3. KONFIGURACJA SUPABASE
# =============================================================================

ENV_FILE="$INSTALL_DIR/admin-panel/.env.local"

if [ -f "$ENV_FILE" ] && grep -q "NEXT_PUBLIC_SUPABASE_URL" "$ENV_FILE"; then
    echo "✅ Konfiguracja Supabase już istnieje"
elif [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ] && [ -n "$SUPABASE_SERVICE_KEY" ]; then
    # Zmienne przekazane z deploy.sh
    echo "✅ Konfiguruję Supabase..."
    mkdir -p "$INSTALL_DIR/admin-panel"
    cat > "$ENV_FILE" <<ENVEOF
# Supabase
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_KEY
ENVEOF
else
    echo "❌ Brak konfiguracji Supabase!"
    echo "   Uruchom deploy.sh interaktywnie lub podaj zmienne:"
    echo "   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY"
    exit 1
fi

# =============================================================================
# 4. KONFIGURACJA STRIPE
# =============================================================================

if grep -q "NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_" "$ENV_FILE" 2>/dev/null; then
    echo "✅ Konfiguracja Stripe już istnieje"
else
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "📋 KONFIGURACJA STRIPE"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Sprawdź zmienne środowiskowe
    if [ -n "$STRIPE_PK" ] && [ -n "$STRIPE_SK" ]; then
        echo "✅ Użyto zmiennych środowiskowych dla Stripe"
        CONFIGURE_STRIPE=true
    elif [ -t 0 ]; then
        echo "GateFlow potrzebuje kluczy Stripe do obsługi płatności."
        echo "Możesz je skonfigurować teraz lub później w panelu GateFlow."
        echo ""
        read -p "Skonfigurować Stripe teraz? [t/N]: " STRIPE_CHOICE

        if [[ "$STRIPE_CHOICE" =~ ^[TtYy1]$ ]]; then
            echo ""
            echo "   1. Otwórz: https://dashboard.stripe.com/apikeys"
            echo "   2. Skopiuj 'Publishable key' (pk_live_... lub pk_test_...)"
            echo "   3. Skopiuj 'Secret key' (sk_live_... lub sk_test_...)"
            echo ""
            read -p "STRIPE_PUBLISHABLE_KEY (pk_...): " STRIPE_PK
            read -p "STRIPE_SECRET_KEY (sk_...): " STRIPE_SK
            read -p "STRIPE_WEBHOOK_SECRET (whsec_..., opcjonalne - Enter aby pominąć): " STRIPE_WEBHOOK_SECRET
            CONFIGURE_STRIPE=true
        else
            echo ""
            echo "⏭️  Pominięto konfigurację Stripe - skonfigurujesz w panelu po instalacji."
            CONFIGURE_STRIPE=false
        fi
    else
        # Tryb nieinteraktywny bez kluczy - pomiń (można skonfigurować w GUI)
        echo "⏭️  Stripe nie skonfigurowany - skonfigurujesz w panelu po instalacji."
        CONFIGURE_STRIPE=false
    fi

    # Dodaj do .env.local tylko jeśli wybrano konfigurację
    if [ "$CONFIGURE_STRIPE" = true ] && [ -n "$STRIPE_PK" ]; then
        cat >> "$ENV_FILE" <<ENVEOF

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=$STRIPE_PK
STRIPE_SECRET_KEY=$STRIPE_SK
STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET:-whsec_TODO_UPDATE_AFTER_WEBHOOK_SETUP}
ENVEOF
    fi
fi

# =============================================================================
# 5. KONFIGURACJA DOMENY I URL
# =============================================================================

if grep -q "NEXT_PUBLIC_SITE_URL=https://" "$ENV_FILE" 2>/dev/null; then
    echo "✅ Konfiguracja URL już istnieje"
else
    if [ -n "$DOMAIN" ]; then
        SITE_URL="https://$DOMAIN"
    elif [ -t 0 ]; then
        echo ""
        read -p "Domena aplikacji (np. app.example.com): " DOMAIN
        SITE_URL="https://$DOMAIN"
    else
        SITE_URL="https://localhost:$PORT"
    fi

    cat >> "$ENV_FILE" <<ENVEOF

# Site URLs
NEXT_PUBLIC_SITE_URL=$SITE_URL
NEXT_PUBLIC_BASE_URL=$SITE_URL
MAIN_DOMAIN=${DOMAIN:-localhost}

# Production
NODE_ENV=production
PORT=$PORT
ENVEOF
fi

chmod 600 "$ENV_FILE"
echo "✅ Konfiguracja zapisana w $ENV_FILE"
echo ""

# =============================================================================
# 6. BUILD APLIKACJI
# =============================================================================

# Sprawdź ilość RAM i ostrzeż użytkownika
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')

if [ "$TOTAL_RAM_MB" -le 1500 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║   ⏳  INSTALACJA MOŻE POTRWAĆ 10-15 MINUT                      ║"
    echo "║                                                                ║"
    echo "║   Twój serwer ma mało pamięci (${TOTAL_RAM_MB}MB RAM).               ║"
    echo "║   Przygotowanie aplikacji zajmie więcej czasu.                ║"
    echo "║                                                                ║"
    echo "║   ⚠️  NIE PRZERYWAJ - to normalne, że długo trwa!              ║"
    echo "║                                                                ║"
    echo "║   Po instalacji aplikacja będzie działać szybko i płynnie.    ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    if [ -t 0 ]; then
        read -p "Naciśnij Enter aby kontynuować..." _
    fi
fi

echo "🛠️  Przygotowuję aplikację..."
cd "$INSTALL_DIR/admin-panel"
bun install
bun run build

echo "✅ Build zakończony"
echo ""

# =============================================================================
# 7. KONFIGURACJA PM2
# =============================================================================

echo "⚙️  Konfiguruję PM2..."

cat > "$INSTALL_DIR/ecosystem.config.js" <<'PMEOF'
module.exports = {
  apps: [{
    name: "gateflow-admin",
    cwd: "./admin-panel",
    script: process.env.HOME + "/.bun/bin/bun",
    args: "run start",
    env: {
      NODE_ENV: "production",
      PORT: 3333
    },
    instances: 1,
    exec_mode: "fork",
    autorestart: true,
    max_memory_restart: "900M",
    error_file: "./admin-panel/logs/error.log",
    out_file: "./admin-panel/logs/out.log"
  }]
};
PMEOF

mkdir -p "$INSTALL_DIR/admin-panel/logs"

# =============================================================================
# 8. START APLIKACJI
# =============================================================================

echo "🚀 Uruchamiam GateFlow..."
cd "$INSTALL_DIR"

# Zatrzymaj jeśli działa
pm2 delete gateflow-admin 2>/dev/null || true

# Uruchom
pm2 start ecosystem.config.js
pm2 save

# Poczekaj i sprawdź
sleep 3

if pm2 list | grep -q "gateflow-admin.*online"; then
    echo "✅ GateFlow działa!"
else
    echo "❌ Problem z uruchomieniem. Logi:"
    pm2 logs gateflow-admin --lines 20
    exit 1
fi

# Health check
sleep 2
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" | grep -q "200\|301\|302"; then
    echo "✅ Aplikacja odpowiada na porcie $PORT"
else
    echo "⚠️  Aplikacja może jeszcze się uruchamiać..."
fi

# Caddy/HTTPS - dla Cloudflare (Cytrus jest obsługiwany przez deploy.sh)
if [ -n "$DOMAIN" ] && command -v mikrus-expose &> /dev/null; then
    # Sprawdź czy to nie jest domena Cytrus
    case "$DOMAIN" in
        *.byst.re|*.bieda.it|*.toadres.pl|*.tojest.dev|*.mikr.us|*.srv24.pl|*.vxm.pl)
            # Cytrus - obsługiwane przez deploy.sh
            ;;
        *)
            # Cloudflare - użyj Caddy
            sudo mikrus-expose "$DOMAIN" "$PORT"
            ;;
    esac
fi

# =============================================================================
# 9. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ GateFlow zainstalowany!"
echo "════════════════════════════════════════════════════════════════"
echo ""
if [ -n "$DOMAIN" ]; then
    echo "🔗 URL: https://$DOMAIN"
else
    echo "🔗 Lokalnie: http://localhost:$PORT"
fi
echo ""
echo "📋 Przydatne komendy:"
echo "   pm2 status              - status aplikacji"
echo "   pm2 logs gateflow-admin - logi"
echo "   pm2 restart gateflow-admin - restart"
echo ""
echo "📋 Następne kroki:"
echo "   1. Otwórz URL - pierwszy user zostanie adminem"
echo "   2. Skonfiguruj Stripe Webhook:"
echo "      → https://dashboard.stripe.com/webhooks"
echo "      → Endpoint: https://$DOMAIN/api/webhooks/stripe"
echo "      → Events: checkout.session.completed, payment_intent.succeeded"
echo "   3. Zaktualizuj STRIPE_WEBHOOK_SECRET w $ENV_FILE"
echo ""
