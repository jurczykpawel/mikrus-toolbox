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
GITHUB_REPO="pavvel11/gateflow"

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
# 2. POBIERANIE PRE-BUILT RELEASE
# =============================================================================

mkdir -p "$INSTALL_DIR/admin-panel"
cd "$INSTALL_DIR/admin-panel"

# Sprawdź czy już mamy pliki (aktualizacja vs świeża instalacja)
if [ -d ".next/standalone" ]; then
    echo "✅ GateFlow już pobrany - używam istniejących plików"
else
    echo "📥 Pobieram GateFlow..."

    # URL do najnowszego releasu (automatyczne przekierowanie)
    RELEASE_URL="https://github.com/$GITHUB_REPO/releases/latest/download/gateflow-build.tar.gz"

    curl -L "$RELEASE_URL" | tar -xz

    if [ ! -d ".next/standalone" ]; then
        echo "❌ Nie udało się pobrać GateFlow."
        echo "   Sprawdź czy repo jest publiczne lub pobierz ręcznie."
        exit 1
    fi

    echo "✅ GateFlow pobrany"
fi
echo ""

# =============================================================================
# 3. KONFIGURACJA SUPABASE
# =============================================================================

ENV_FILE="$INSTALL_DIR/admin-panel/.env.local"

if [ -f "$ENV_FILE" ] && grep -q "SUPABASE_URL=" "$ENV_FILE"; then
    echo "✅ Konfiguracja Supabase już istnieje"
elif [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ] && [ -n "$SUPABASE_SERVICE_KEY" ]; then
    # Zmienne przekazane z deploy.sh
    echo "✅ Konfiguruję Supabase..."
    cat > "$ENV_FILE" <<ENVEOF
# Supabase (runtime - bez NEXT_PUBLIC_)
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_KEY

# Legacy (dla kompatybilności)
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
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

if grep -q "STRIPE_PUBLISHABLE_KEY=pk_" "$ENV_FILE" 2>/dev/null; then
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
STRIPE_PUBLISHABLE_KEY=$STRIPE_PK
STRIPE_SECRET_KEY=$STRIPE_SK
STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET:-}
ENVEOF
    fi
fi

# =============================================================================
# 5. KONFIGURACJA DOMENY I URL
# =============================================================================

if grep -q "SITE_URL=https://" "$ENV_FILE" 2>/dev/null; then
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

# Site URLs (runtime)
SITE_URL=$SITE_URL
MAIN_DOMAIN=${DOMAIN:-localhost}

# Legacy (dla kompatybilności)
NEXT_PUBLIC_SITE_URL=$SITE_URL
NEXT_PUBLIC_BASE_URL=$SITE_URL

# Production
NODE_ENV=production
PORT=$PORT
ENVEOF
fi

chmod 600 "$ENV_FILE"
echo "✅ Konfiguracja zapisana w $ENV_FILE"
echo ""

# =============================================================================
# 6. KOPIOWANIE ENV DO STANDALONE
# =============================================================================

echo "📋 Konfiguruję standalone server..."

STANDALONE_DIR="$INSTALL_DIR/admin-panel/.next/standalone/admin-panel"

if [ -d "$STANDALONE_DIR" ]; then
    cp "$ENV_FILE" "$STANDALONE_DIR/.env.local"
    echo "✅ Konfiguracja skopiowana do standalone"
else
    echo "⚠️  Brak folderu standalone - używam standardowego startu"
fi

# =============================================================================
# 7. START APLIKACJI
# =============================================================================

echo "🚀 Uruchamiam GateFlow..."

# Zatrzymaj jeśli działa
pm2 delete gateflow-admin 2>/dev/null || true

# Uruchom - preferuj standalone server (szybszy start, mniej RAM)
if [ -f "$STANDALONE_DIR/server.js" ]; then
    cd "$STANDALONE_DIR"
    PORT=$PORT HOSTNAME=0.0.0.0 pm2 start "node server.js" --name gateflow-admin
else
    # Fallback do bun run start
    cd "$INSTALL_DIR/admin-panel"
    pm2 start "bun run start" --name gateflow-admin
fi

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
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ Aplikacja odpowiada na porcie $PORT (HTTP $HTTP_CODE)"
else
    echo "⚠️  Aplikacja może jeszcze się uruchamiać... (HTTP $HTTP_CODE)"
fi

# =============================================================================
# 8. PODSUMOWANIE
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
