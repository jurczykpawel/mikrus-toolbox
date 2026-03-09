#!/bin/bash

# Mikrus Toolbox - Sellf
# Self-hosted digital products sales platform (Gumroad/EasyCart alternative)
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=500  # sellf (Next.js app ~500MB)
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

APP_NAME="sellf"
GITHUB_REPO="jurczykpawel/sellf"

# =============================================================================
# MULTI-INSTANCE: nazwa instancji z domeny
# =============================================================================
# Wyciągnij pierwszą część domeny jako nazwę instancji
# shop.example.com → shop
# abc123.byst.re → abc123
#
# UWAGA: Auto-cytrus (DOMAIN="-") = tylko SINGLE INSTANCE!
# Dla multi-instance musisz podać konkretne domeny z góry.
# Drugie wywołanie z DOMAIN="-" nadpisałoby pierwszy katalog.
#
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    INSTANCE_NAME="${DOMAIN%%.*}"
else
    INSTANCE_NAME=""
fi

# Ustaw ścieżki i nazwy na podstawie instancji
# Instalujemy do /opt/stacks żeby backup działał automatycznie
if [ -n "$INSTANCE_NAME" ]; then
    INSTALL_DIR="/opt/stacks/sellf-${INSTANCE_NAME}"
    PM2_NAME="sellf-${INSTANCE_NAME}"
else
    INSTALL_DIR="/opt/stacks/sellf"
    PM2_NAME="sellf"

    # Sprawdź czy katalog już istnieje (zapobiegaj nadpisaniu przy auto-cytrus)
    if [ -d "$INSTALL_DIR/admin-panel" ] && [ -f "$INSTALL_DIR/admin-panel/.env.local" ]; then
        echo "❌ Katalog $INSTALL_DIR już istnieje!"
        echo ""
        echo "   Auto-cytrus (--domain=-) wspiera tylko JEDNĄ instancję."
        echo "   Dla wielu instancji użyj konkretnych domen:"
        echo "   ./local/deploy.sh sellf --domain=shop.example.com"
        echo "   ./local/deploy.sh sellf --domain=test.example.com"
        echo ""
        echo "   Lub usuń istniejącą instalację:"
        echo "   pm2 delete sellf && rm -rf $INSTALL_DIR"
        exit 1
    fi
fi

PORT=${PORT:-3333}

echo "--- 💰 Sellf Setup ---"
echo ""
if [ -n "$INSTANCE_NAME" ]; then
    echo "📦 Instancja: $INSTANCE_NAME"
    echo "   Katalog: $INSTALL_DIR"
    echo "   PM2: $PM2_NAME"
    echo ""
fi

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

# Dodaj PATH do rc pliku powłoki (żeby pm2 działał przez SSH)
# Sprawdzamy $SHELL żeby wybrać właściwy plik
add_path_to_rc() {
    local RC_FILE="$1"
    local PREPEND="${2:-false}"

    if [ "$PREPEND" = "true" ] && [ -f "$RC_FILE" ]; then
        # Dodaj na początku (bash - przed guardem [ -z "$PS1" ] && return)
        {
            echo '# Bun & PM2 (dodane przez mikrus-toolbox)'
            echo 'export PATH="$HOME/.bun/bin:$PATH"'
            echo ''
            cat "$RC_FILE"
        } > "${RC_FILE}.new"
        mv "${RC_FILE}.new" "$RC_FILE"
    else
        # Dodaj na końcu (zsh, profile)
        echo '' >> "$RC_FILE"
        echo '# Bun & PM2 (dodane przez mikrus-toolbox)' >> "$RC_FILE"
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$RC_FILE"
    fi
}

# Sprawdź czy PATH już dodany do któregoś z plików
if ! grep -q '\.bun/bin' ~/.bashrc 2>/dev/null && \
   ! grep -q '\.bun/bin' ~/.zshrc 2>/dev/null && \
   ! grep -q '\.bun/bin' ~/.profile 2>/dev/null; then

    # Wybierz plik na podstawie powłoki użytkownika
    case "$SHELL" in
        */zsh)
            add_path_to_rc ~/.zshrc false
            echo "✅ Dodano PATH do ~/.zshrc"
            ;;
        */bash)
            if [ -f ~/.bashrc ]; then
                add_path_to_rc ~/.bashrc true
                echo "✅ Dodano PATH do ~/.bashrc"
            else
                add_path_to_rc ~/.profile false
                echo "✅ Dodano PATH do ~/.profile"
            fi
            ;;
        *)
            # Nieznana powłoka - użyj .profile (uniwersalne)
            add_path_to_rc ~/.profile false
            echo "✅ Dodano PATH do ~/.profile"
            ;;
    esac
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
    echo "✅ Sellf już pobrany - używam istniejących plików"
else
    echo "📥 Pobieram Sellf..."

    # Sprawdź czy mamy lokalny plik (przekazany przez deploy.sh)
    if [ -n "$BUILD_FILE" ] && [ -f "$BUILD_FILE" ]; then
        echo "   Używam pliku: $BUILD_FILE"
        if ! tar -xzf "$BUILD_FILE"; then
            echo ""
            echo "❌ Nie udało się rozpakować pliku"
            echo "   Upewnij się, że plik jest prawidłowym archiwum .tar.gz"
            exit 1
        fi
    else
        # Pobierz z GitHub
        # Spróbuj /latest (wymaga oznaczonego "latest release" na GitHub)
        RELEASE_URL="https://github.com/$GITHUB_REPO/releases/latest/download/sellf-build.tar.gz"

        if ! curl -fsSL "$RELEASE_URL" 2>/dev/null | tar -xz 2>/dev/null; then
            # Fallback: znajdź najnowszy release z artefaktem sellf-build.tar.gz
            echo "   /latest niedostępny, szukam najnowszego releasu z buildem..."
            RELEASE_URL=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases" 2>/dev/null \
                | grep -m1 "browser_download_url.*sellf-build" | sed 's/.*: "\(.*\)".*/\1/')

            if [ -n "$RELEASE_URL" ]; then
                LATEST_TAG=$(echo "$RELEASE_URL" | sed 's|.*/download/\([^/]*\)/.*|\1|')
                echo "   Znaleziono: $LATEST_TAG"
                if ! curl -fsSL "$RELEASE_URL" | tar -xz; then
                    echo ""
                    echo "❌ Nie udało się pobrać Sellf ($LATEST_TAG)"
                    exit 1
                fi
            else
                echo ""
                echo "❌ Nie udało się pobrać Sellf z GitHub"
                echo ""
                echo "   Możliwe przyczyny:"
                echo "   • Brak releasu z artefaktem sellf-build.tar.gz"
                echo "   • Repozytorium jest prywatne"
                echo "   • Brak połączenia z internetem"
                echo ""
                echo "   Rozwiązanie: Pobierz plik ręcznie i użyj flagi --build-file:"
                echo "   ./local/deploy.sh sellf --ssh=mikrus --build-file=~/Downloads/sellf-build.tar.gz"
                exit 1
            fi
        fi
    fi

    if [ ! -d ".next/standalone" ]; then
        echo ""
        echo "❌ Nieprawidłowa struktura archiwum"
        echo "   Archiwum powinno zawierać folder .next/standalone"
        exit 1
    fi

    echo "✅ Sellf pobrany"
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

# Klucz szyfrujący dla integracji (Stripe UI wizard, GUS, Currency API)
# AES-256-GCM - NIE ZMIENIAJ! Utrata klucza = reset konfiguracji integracji
APP_ENCRYPTION_KEY=$(openssl rand -base64 32)
ENVEOF
else
    echo "❌ Brak konfiguracji Supabase!"
    echo "   Uruchom deploy.sh interaktywnie lub podaj zmienne:"
    echo "   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY"
    exit 1
fi

# Upewnij się że APP_ENCRYPTION_KEY istnieje (dla starszych instalacji)
if ! grep -q "APP_ENCRYPTION_KEY=" "$ENV_FILE" 2>/dev/null; then
    echo "🔐 Generuję klucz szyfrujący..."
    cat >> "$ENV_FILE" <<ENVEOF

# Klucz szyfrujący dla integracji (Stripe UI wizard, GUS, Currency API)
# AES-256-GCM - NIE ZMIENIAJ! Utrata klucza = reset konfiguracji integracji
APP_ENCRYPTION_KEY=$(openssl rand -base64 32)
ENVEOF
fi

# =============================================================================
# 4. KONFIGURACJA STRIPE
# =============================================================================

if grep -q "STRIPE_PUBLISHABLE_KEY" "$ENV_FILE" 2>/dev/null; then
    echo "✅ Konfiguracja Stripe już istnieje"
elif [ -n "$STRIPE_PK" ] && [ -n "$STRIPE_SK" ]; then
    # Użyj kluczy przekazanych przez deploy.sh (zebrane lokalnie w FAZIE 1.5)
    echo "✅ Konfiguruję Stripe..."
    cat >> "$ENV_FILE" <<ENVEOF

# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=$STRIPE_PK
STRIPE_SECRET_KEY=$STRIPE_SK
STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET:-}
STRIPE_COLLECT_TERMS_OF_SERVICE=false
ENVEOF
else
    # Brak kluczy - dodaj placeholdery (skonfiguruje w UI)
    echo "ℹ️  Stripe zostanie skonfigurowany w panelu po instalacji"
    cat >> "$ENV_FILE" <<ENVEOF

# Stripe Configuration (skonfiguruj przez UI wizard w panelu)
STRIPE_PUBLISHABLE_KEY=
STRIPE_SECRET_KEY=
STRIPE_COLLECT_TERMS_OF_SERVICE=false
ENVEOF
fi

# =============================================================================
# 5. KONFIGURACJA DOMENY I URL
# =============================================================================

# Dla auto-Cytrus (DOMAIN="-"), pomiń konfigurację URL - deploy.sh zaktualizuje po otrzymaniu domeny
if [ "$DOMAIN" = "-" ]; then
    echo "⏳ Domena zostanie skonfigurowana po przydzieleniu przez Cytrus"
    # Ustaw tylko PORT i HOSTNAME żeby serwer wystartował
    cat >> "$ENV_FILE" <<ENVEOF

# Production (domena zostanie dodana przez deploy.sh)
NODE_ENV=production
PORT=$PORT
HOSTNAME=::
NEXT_TELEMETRY_DISABLED=1
ENVEOF
elif grep -q "SITE_URL=https://" "$ENV_FILE" 2>/dev/null; then
    echo "✅ Konfiguracja URL już istnieje"
else
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
        SITE_URL="https://$DOMAIN"
    elif [ -t 0 ]; then
        echo ""
        read -p "Domena aplikacji (np. app.example.com): " DOMAIN
        SITE_URL="https://$DOMAIN"
    else
        SITE_URL="https://localhost:$PORT"
        DOMAIN="localhost"
    fi

    # Sprawdź czy to domena Cytrus (reverse proxy z SSL termination)
    DISABLE_HSTS="false"
    case "$DOMAIN" in
        *.byst.re|*.bieda.it|*.toadres.pl|*.tojest.dev|*.mikr.us|*.srv24.pl|*.vxm.pl)
            DISABLE_HSTS="true"
            ;;
    esac

    cat >> "$ENV_FILE" <<ENVEOF

# Site URLs (runtime)
SITE_URL=$SITE_URL
MAIN_DOMAIN=$DOMAIN

# Production
NODE_ENV=production
PORT=$PORT
# :: słucha na IPv4 i IPv6 (wymagane dla Cytrus który łączy się przez IPv6)
HOSTNAME=::
NEXT_TELEMETRY_DISABLED=1

# HSTS (wyłącz dla reverse proxy z SSL termination)
DISABLE_HSTS=$DISABLE_HSTS
ENVEOF
fi

# =============================================================================
# 5.1. KONFIGURACJA TURNSTILE (jeśli przekazano klucze)
# =============================================================================

if [ -n "$CLOUDFLARE_TURNSTILE_SITE_KEY" ] && [ -n "$CLOUDFLARE_TURNSTILE_SECRET_KEY" ]; then
    if ! grep -q "CLOUDFLARE_TURNSTILE_SITE_KEY" "$ENV_FILE" 2>/dev/null; then
        cat >> "$ENV_FILE" <<ENVEOF

# Cloudflare Turnstile (CAPTCHA)
CLOUDFLARE_TURNSTILE_SITE_KEY=$CLOUDFLARE_TURNSTILE_SITE_KEY
CLOUDFLARE_TURNSTILE_SECRET_KEY=$CLOUDFLARE_TURNSTILE_SECRET_KEY
# Alias dla Supabase Auth
TURNSTILE_SECRET_KEY=$CLOUDFLARE_TURNSTILE_SECRET_KEY
ENVEOF
        echo "✅ Turnstile skonfigurowany"
    fi
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
    # Kopiuj konfigurację
    cp "$ENV_FILE" "$STANDALONE_DIR/.env.local"

    # Kopiuj pliki statyczne (wymagane dla standalone mode)
    cp -r "$INSTALL_DIR/admin-panel/.next/static" "$STANDALONE_DIR/.next/" 2>/dev/null || true
    cp -r "$INSTALL_DIR/admin-panel/public" "$STANDALONE_DIR/" 2>/dev/null || true

    echo "✅ Standalone skonfigurowany (env + static files)"
else
    echo "⚠️  Brak folderu standalone - używam standardowego startu"
fi

# =============================================================================
# 7. START APLIKACJI
# =============================================================================

echo "🚀 Uruchamiam Sellf..."

# Zatrzymaj jeśli działa
pm2 delete $PM2_NAME 2>/dev/null || true

# Uruchom - preferuj standalone server (szybszy start, mniej RAM)
if [ -f "$STANDALONE_DIR/server.js" ]; then
    cd "$STANDALONE_DIR"

    # Załaduj zmienne z .env.local i uruchom PM2 w tej samej sesji
    # (PM2 dziedziczy zmienne środowiskowe z bieżącej sesji)
    # Wyczyść systemowy HOSTNAME (to nazwa maszyny, nie adres nasłuchiwania)
    unset HOSTNAME
    set -a
    source .env.local
    set +a
    export PORT="${PORT:-3333}"
    # :: słucha na IPv4 i IPv6 (wymagane dla Cytrus który łączy się przez IPv6)
    export HOSTNAME="${HOSTNAME:-::}"

    # WAŻNE: użyj --interpreter node, NIE "node server.js" w cudzysłowach
    # Cudzysłowy uruchamiają przez bash, który nie dziedziczy zmiennych środowiskowych
    pm2 start server.js --name $PM2_NAME --interpreter node
else
    # Fallback do bun run start
    cd "$INSTALL_DIR/admin-panel"
    pm2 start server.js --name $PM2_NAME --interpreter bun
fi

pm2 save

# Poczekaj i sprawdź
sleep 3

if pm2 list | grep -q "$PM2_NAME.*online"; then
    echo "✅ Sellf działa!"
else
    echo "❌ Problem z uruchomieniem. Logi:"
    pm2 logs $PM2_NAME --lines 20
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
# 8. PODSUMOWANIE (skrócone - pełne info w deploy.sh po przydzieleniu domeny)
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Sellf zainstalowany!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Przydatne komendy:"
echo "   pm2 status              - status aplikacji"
echo "   pm2 logs $PM2_NAME - logi"
echo "   pm2 restart $PM2_NAME - restart"
echo ""
