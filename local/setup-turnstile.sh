#!/bin/bash

# Mikrus Toolbox - Turnstile Setup
# Automatycznie konfiguruje Cloudflare Turnstile (CAPTCHA) dla aplikacji.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/setup-turnstile.sh <domena> [ssh_alias]
#
# Przykłady:
#   ./local/setup-turnstile.sh app.example.com mikrus
#   ./local/setup-turnstile.sh myapp.example.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/server-exec.sh"

DOMAIN="$1"
SSH_ALIAS="${2:-mikrus}"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguracja
CONFIG_DIR="$HOME/.config/cloudflare"
CONFIG_FILE="$CONFIG_DIR/config"
TURNSTILE_TOKEN_FILE="$CONFIG_DIR/turnstile_token"
TURNSTILE_ACCOUNT_FILE="$CONFIG_DIR/turnstile_account_id"

if [ -z "$DOMAIN" ]; then
    echo "Użycie: $0 <domena> [ssh_alias]"
    echo ""
    echo "Przykłady:"
    echo "  $0 app.example.com mikrus"
    echo "  $0 myapp.example.com"
    exit 1
fi

echo ""
echo -e "${BLUE}🔒 Turnstile Setup${NC}"
echo "   Domena: $DOMAIN"
echo ""

# =============================================================================
# 1. SPRAWDŹ ISTNIEJĄCY TOKEN
# =============================================================================

get_account_id() {
    local TOKEN="$1"

    # Pobierz account ID z dowolnej strefy
    if [ -f "$CONFIG_FILE" ]; then
        local ZONE_ID=$(grep "\.pl=\|\.com=\|\.dev=\|\.org=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d= -f2)
        if [ -n "$ZONE_ID" ]; then
            curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" | \
                grep -o '"account":{[^}]*}' | grep -o '"id":"[^"]*"' | cut -d'"' -f4
        fi
    fi
}

check_turnstile_access() {
    local TOKEN="$1"
    local ACCOUNT_ID="$2"

    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json")

    if echo "$RESPONSE" | grep -q '"success":true'; then
        return 0
    else
        return 1
    fi
}

# Sprawdź czy mamy token z uprawnieniami Turnstile
TURNSTILE_TOKEN=""
ACCOUNT_ID=""

# Spróbuj załadować zapisane dane
if [ -f "$TURNSTILE_TOKEN_FILE" ]; then
    TURNSTILE_TOKEN=$(cat "$TURNSTILE_TOKEN_FILE")
fi
if [ -f "$TURNSTILE_ACCOUNT_FILE" ]; then
    ACCOUNT_ID=$(cat "$TURNSTILE_ACCOUNT_FILE")
fi

# Zweryfikuj zapisany token
if [ -n "$TURNSTILE_TOKEN" ] && [ -n "$ACCOUNT_ID" ]; then
    echo "🔑 Znaleziono zapisany token Turnstile..."
    if check_turnstile_access "$TURNSTILE_TOKEN" "$ACCOUNT_ID"; then
        echo -e "${GREEN}   ✅ Token jest aktualny${NC}"
    else
        echo "   ⚠️  Token wygasł lub jest nieprawidłowy"
        TURNSTILE_TOKEN=""
        ACCOUNT_ID=""
        rm -f "$TURNSTILE_TOKEN_FILE" "$TURNSTILE_ACCOUNT_FILE"
    fi
fi

# Jeśli nie ma dedykowanego tokena, spróbuj głównego
if [ -z "$TURNSTILE_TOKEN" ] && [ -f "$CONFIG_FILE" ]; then
    MAIN_TOKEN=$(grep "^API_TOKEN=" "$CONFIG_FILE" | cut -d= -f2)
    if [ -n "$MAIN_TOKEN" ]; then
        ACCOUNT_ID=$(get_account_id "$MAIN_TOKEN")
        if [ -n "$ACCOUNT_ID" ] && check_turnstile_access "$MAIN_TOKEN" "$ACCOUNT_ID"; then
            TURNSTILE_TOKEN="$MAIN_TOKEN"
            echo -e "${GREEN}✅ Główny token ma uprawnienia Turnstile${NC}"
            # Zapisz Account ID dla przyszłych użyć
            mkdir -p "$CONFIG_DIR"
            echo "$ACCOUNT_ID" > "$TURNSTILE_ACCOUNT_FILE"
            chmod 600 "$TURNSTILE_ACCOUNT_FILE"
        fi
    fi
fi

# =============================================================================
# 2. JEŚLI BRAK TOKENA - POPROŚ O NOWY
# =============================================================================

if [ -z "$TURNSTILE_TOKEN" ] || [ -z "$ACCOUNT_ID" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Brak tokena z uprawnieniami Turnstile${NC}"
    echo ""
    echo "Potrzebuję token API z uprawnieniem: Account → Turnstile → Edit"
    echo ""
    echo "Krok po kroku:"
    echo "   1. Otwórz: https://dash.cloudflare.com/profile/api-tokens"
    echo "   2. Kliknij 'Create Token'"
    echo "   3. Wybierz 'Create Custom Token'"
    echo "   4. Nazwa: 'Turnstile API'"
    echo "   5. Permissions:"
    echo "      • Account → Turnstile → Edit"
    echo "   6. Account Resources: Include → All accounts (lub wybierz konkretne)"
    echo "   7. Kliknij 'Continue to summary' → 'Create Token'"
    echo "   8. Skopiuj token"
    echo ""

    read -p "Naciśnij Enter aby otworzyć Cloudflare..." _

    # Otwórz przeglądarkę
    if command -v open &>/dev/null; then
        open "https://dash.cloudflare.com/profile/api-tokens"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://dash.cloudflare.com/profile/api-tokens"
    fi

    echo ""
    read -p "Wklej token Turnstile: " TURNSTILE_TOKEN

    if [ -z "$TURNSTILE_TOKEN" ]; then
        echo -e "${RED}❌ Token nie może być pusty${NC}"
        exit 1
    fi

    # Pobierz account ID
    echo ""
    echo "🔍 Weryfikuję token..."

    # Najpierw spróbuj pobrać Account ID z głównego tokena CF (ma uprawnienia Zone)
    if [ -z "$ACCOUNT_ID" ] && [ -f "$CONFIG_FILE" ]; then
        MAIN_TOKEN=$(grep "^API_TOKEN=" "$CONFIG_FILE" | cut -d= -f2)
        if [ -n "$MAIN_TOKEN" ]; then
            ACCOUNT_ID=$(get_account_id "$MAIN_TOKEN")
        fi
    fi

    # Jeśli nadal brak - spróbuj z nowego tokena (wymaga Account:Read)
    if [ -z "$ACCOUNT_ID" ]; then
        ACCOUNTS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
            -H "Authorization: Bearer $TURNSTILE_TOKEN" \
            -H "Content-Type: application/json")

        if echo "$ACCOUNTS_RESPONSE" | grep -q '"success":true'; then
            ACCOUNT_ID=$(echo "$ACCOUNTS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        fi
    fi

    # Ostatnia deska ratunku - zapytaj użytkownika
    if [ -z "$ACCOUNT_ID" ]; then
        echo ""
        echo -e "${YELLOW}Nie mogę automatycznie pobrać Account ID.${NC}"
        echo "Znajdziesz go na: https://dash.cloudflare.com → dowolna domena → Overview → Account ID (prawa strona)"
        echo ""
        read -p "Wklej Account ID: " ACCOUNT_ID

        if [ -z "$ACCOUNT_ID" ]; then
            echo -e "${RED}❌ Account ID jest wymagane${NC}"
            exit 1
        fi
    fi

    # Sprawdź uprawnienia Turnstile
    if ! check_turnstile_access "$TURNSTILE_TOKEN" "$ACCOUNT_ID"; then
        echo -e "${RED}❌ Token nie ma uprawnień do Turnstile${NC}"
        echo "   Upewnij się że dodałeś: Account → Turnstile → Edit"
        exit 1
    fi

    echo -e "${GREEN}✅ Token zweryfikowany!${NC}"

    # Zapisz token i Account ID
    mkdir -p "$CONFIG_DIR"
    echo "$TURNSTILE_TOKEN" > "$TURNSTILE_TOKEN_FILE"
    echo "$ACCOUNT_ID" > "$TURNSTILE_ACCOUNT_FILE"
    chmod 600 "$TURNSTILE_TOKEN_FILE" "$TURNSTILE_ACCOUNT_FILE"
    echo "   Token i Account ID zapisane"
fi

# =============================================================================
# 3. SPRAWDŹ CZY WIDGET JUŻ ISTNIEJE
# =============================================================================

echo ""
echo "🔍 Sprawdzam istniejące widgety Turnstile..."

WIDGETS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets" \
    -H "Authorization: Bearer $TURNSTILE_TOKEN" \
    -H "Content-Type: application/json")

# Parsuj widgety przez Python aby prawidłowo obsłużyć JSON
MATCHING_WIDGETS=$(echo "$WIDGETS_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'result' in data:
        for widget in data['result']:
            domains = widget.get('domains', [])
            if '$DOMAIN' in domains:
                print(json.dumps({
                    'sitekey': widget.get('sitekey'),
                    'name': widget.get('name'),
                    'domains': domains,
                    'mode': widget.get('mode')
                }))
except Exception as e:
    pass
" 2>/dev/null)

if [ -n "$MATCHING_WIDGETS" ]; then
    # Zlicz ile widgetów pasuje
    WIDGET_COUNT=$(echo "$MATCHING_WIDGETS" | wc -l | xargs)

    echo -e "${YELLOW}⚠️  Znaleziono $WIDGET_COUNT widget(y) dla domeny $DOMAIN${NC}"
    echo ""

    # Wyświetl wszystkie znalezione widgety
    WIDGET_NUM=1
    declare -a SITEKEYS

    while IFS= read -r widget_json; do
        WIDGET_NAME=$(echo "$widget_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('name', 'N/A'))")
        WIDGET_SITEKEY=$(echo "$widget_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('sitekey', ''))")
        WIDGET_MODE=$(echo "$widget_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('mode', 'N/A'))")

        SITEKEYS[$WIDGET_NUM]="$WIDGET_SITEKEY"

        # Sprawdź czy mamy zapisane klucze dla tego widgeta
        KEYS_FILE="$CONFIG_DIR/turnstile_keys_${WIDGET_SITEKEY}"
        HAS_KEYS=""
        if [ -f "$KEYS_FILE" ]; then
            HAS_KEYS=" ${GREEN}✓ Klucze zapisane${NC}"
        fi

        echo -e "  ${WIDGET_NUM}) Nazwa: $WIDGET_NAME"
        echo "     Site Key: $WIDGET_SITEKEY"
        echo "     Mode: $WIDGET_MODE$HAS_KEYS"
        echo ""

        WIDGET_NUM=$((WIDGET_NUM + 1))
    done <<< "$MATCHING_WIDGETS"

    echo "Opcje:"
    echo "  [1-$WIDGET_COUNT] Użyj istniejącego widgeta"
    echo "  [n] Utwórz nowy widget"
    echo "  [d] Usuń wybrany widget i utwórz nowy"
    echo "  [q] Anuluj"
    echo ""
    read -p "Wybierz opcję: " WIDGET_CHOICE

    case "$WIDGET_CHOICE" in
        [1-9]*)
            # Sprawdź czy numer jest w zakresie
            if [ "$WIDGET_CHOICE" -ge 1 ] && [ "$WIDGET_CHOICE" -le "$WIDGET_COUNT" ]; then
                SITE_KEY="${SITEKEYS[$WIDGET_CHOICE]}"

                # Sprawdź czy mamy zapisane klucze
                KEYS_FILE="$CONFIG_DIR/turnstile_keys_${SITE_KEY}"
                if [ -f "$KEYS_FILE" ]; then
                    echo -e "${GREEN}✅ Używam widgeta ze Site Key: $SITE_KEY${NC}"
                    source "$KEYS_FILE"
                    echo "   Site Key: $CLOUDFLARE_TURNSTILE_SITE_KEY"
                    echo "   Secret Key: ${CLOUDFLARE_TURNSTILE_SECRET_KEY:0:20}..."
                    echo ""
                    echo -e "${GREEN}🎉 Turnstile skonfigurowany!${NC}"

                    # Zapisz również pod nazwą domeny dla kompatybilności
                    DOMAIN_KEYS_FILE="$CONFIG_DIR/turnstile_keys_$DOMAIN"
                    cp "$KEYS_FILE" "$DOMAIN_KEYS_FILE"

                    exit 0
                else
                    echo ""
                    echo -e "${YELLOW}⚠️  Nie mam zapisanego Secret Key dla tego widgeta.${NC}"
                    echo ""
                    echo "Secret Key jest widoczny tylko przy tworzeniu widgeta."
                    echo "Możesz:"
                    echo "  1. Wpisać Secret Key ręcznie (jeśli go masz)"
                    echo "  2. Usunąć widget i utworzyć nowy"
                    echo ""
                    read -p "Wpisać Secret Key ręcznie? [t/N]: " MANUAL_KEY

                    if [[ "$MANUAL_KEY" =~ ^[TtYy]$ ]]; then
                        read -p "Wklej Secret Key: " SECRET_KEY
                        if [ -n "$SECRET_KEY" ]; then
                            # Zapisz klucze
                            echo "CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY" > "$KEYS_FILE"
                            echo "CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY" >> "$KEYS_FILE"
                            chmod 600 "$KEYS_FILE"

                            # Zapisz również pod nazwą domeny
                            DOMAIN_KEYS_FILE="$CONFIG_DIR/turnstile_keys_$DOMAIN"
                            cp "$KEYS_FILE" "$DOMAIN_KEYS_FILE"

                            echo -e "${GREEN}✅ Klucze zapisane!${NC}"
                            echo -e "${GREEN}🎉 Turnstile skonfigurowany!${NC}"
                            exit 0
                        fi
                    fi

                    echo ""
                    echo "Uruchom ponownie skrypt i wybierz opcję [d] aby usunąć widget i utworzyć nowy."
                    exit 0
                fi
            else
                echo -e "${RED}❌ Nieprawidłowy wybór${NC}"
                exit 1
            fi
            ;;
        [dD])
            echo ""
            echo "Który widget usunąć?"
            read -p "Numer [1-$WIDGET_COUNT]: " DELETE_NUM

            if [ "$DELETE_NUM" -ge 1 ] && [ "$DELETE_NUM" -le "$WIDGET_COUNT" ]; then
                SITE_KEY="${SITEKEYS[$DELETE_NUM]}"

                echo ""
                echo -e "${YELLOW}⚠️  UWAGA: Usunięcie widgeta spowoduje że wszystkie aplikacje używające tego Site Key przestaną działać!${NC}"
                echo ""
                read -p "Czy na pewno usunąć widget $SITE_KEY? [t/N]: " CONFIRM_DELETE

                if [[ "$CONFIRM_DELETE" =~ ^[TtYy]$ ]]; then
                    echo "🗑️  Usuwam widget..."
                    DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets/$SITE_KEY" \
                        -H "Authorization: Bearer $TURNSTILE_TOKEN" \
                        -H "Content-Type: application/json")

                    if echo "$DELETE_RESPONSE" | grep -q '"success":true'; then
                        echo -e "${GREEN}✅ Widget usunięty${NC}"

                        # Usuń zapisane klucze
                        rm -f "$CONFIG_DIR/turnstile_keys_${SITE_KEY}" "$CONFIG_DIR/turnstile_keys_$DOMAIN"

                        # Kontynuuj do tworzenia nowego widgeta (nie exit)
                    else
                        echo -e "${RED}❌ Nie udało się usunąć widgeta${NC}"
                        exit 1
                    fi
                else
                    exit 0
                fi
            else
                echo -e "${RED}❌ Nieprawidłowy wybór${NC}"
                exit 1
            fi
            ;;
        [nN])
            echo ""
            echo "Tworzę nowy widget..."
            # Kontynuuj do sekcji tworzenia widgeta
            ;;
        [qQ])
            echo "Anulowano."
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Nieprawidłowy wybór${NC}"
            exit 1
            ;;
    esac
fi

# =============================================================================
# 4. UTWÓRZ NOWY WIDGET
# =============================================================================

echo ""
echo "🔧 Tworzę widget Turnstile dla $DOMAIN..."

CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets" \
    -H "Authorization: Bearer $TURNSTILE_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
        \"name\": \"$DOMAIN\",
        \"domains\": [\"$DOMAIN\"],
        \"mode\": \"managed\",
        \"bot_fight_mode\": false,
        \"clearance_level\": \"no_clearance\"
    }")

if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
    SITE_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"sitekey":"[^"]*"' | cut -d'"' -f4)
    SECRET_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"secret":"[^"]*"' | cut -d'"' -f4)

    echo -e "${GREEN}✅ Widget utworzony!${NC}"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "   CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY"
    echo "   CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Zapisz klucze do pliku (dla deploy.sh)
    # Zapisz zarówno pod nazwą domeny jak i Site Key dla łatwiejszego odnalezienia
    KEYS_FILE_DOMAIN="$CONFIG_DIR/turnstile_keys_$DOMAIN"
    KEYS_FILE_SITEKEY="$CONFIG_DIR/turnstile_keys_${SITE_KEY}"

    echo "CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY" > "$KEYS_FILE_DOMAIN"
    echo "CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY" >> "$KEYS_FILE_DOMAIN"
    chmod 600 "$KEYS_FILE_DOMAIN"

    # Kopia dla Site Key (aby móc odnaleźć przy ponownym użyciu)
    cp "$KEYS_FILE_DOMAIN" "$KEYS_FILE_SITEKEY"
    chmod 600 "$KEYS_FILE_SITEKEY"

    echo "💾 Klucze zapisane w: $KEYS_FILE_DOMAIN"

    # Dodaj do .env.local na serwerze (jeśli podano SSH_ALIAS)
    if [ -n "$SSH_ALIAS" ]; then
        echo ""
        echo "📤 Dodaję klucze do serwera $SSH_ALIAS..."

        # Wyznacz ścieżki na podstawie domeny (multi-instance support)
        # Nowa lokalizacja: /opt/stacks/sellf*
        INSTANCE_NAME="${DOMAIN%%.*}"
        SELLF_DIR="/opt/stacks/sellf-${INSTANCE_NAME}"
        PM2_NAME="sellf-${INSTANCE_NAME}"

        # Sprawdź czy istnieje katalog instancji, jeśli nie - szukaj dalej
        if ! server_exec "test -d $SELLF_DIR" 2>/dev/null; then
            SELLF_DIR="/opt/stacks/sellf"
            PM2_NAME="sellf"
        fi
        # Fallback do starej lokalizacji
        if ! server_exec "test -d $SELLF_DIR" 2>/dev/null; then
            SELLF_DIR="/root/sellf-${INSTANCE_NAME}"
            PM2_NAME="sellf-${INSTANCE_NAME}"
        fi
        if ! server_exec "test -d $SELLF_DIR" 2>/dev/null; then
            SELLF_DIR="/root/sellf"
            PM2_NAME="sellf"
        fi

        ENV_FILE="$SELLF_DIR/admin-panel/.env.local"
        STANDALONE_ENV="$SELLF_DIR/admin-panel/.next/standalone/admin-panel/.env.local"

        # Sprawdź czy istnieje
        if server_exec "test -f $ENV_FILE" 2>/dev/null; then
            # Dodaj do głównego .env.local (z aliasem TURNSTILE_SECRET_KEY dla Supabase)
            server_exec "echo '' >> $ENV_FILE && echo '# Cloudflare Turnstile' >> $ENV_FILE && echo 'CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY' >> $ENV_FILE && echo 'CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY' >> $ENV_FILE && echo 'TURNSTILE_SECRET_KEY=$SECRET_KEY' >> $ENV_FILE"

            # Skopiuj do standalone
            server_exec "cp $ENV_FILE $STANDALONE_ENV 2>/dev/null || true"

            echo -e "${GREEN}   ✅ Klucze dodane${NC}"

            # Restart PM2 z przeładowaniem zmiennych środowiskowych
            echo "🔄 Restartuję Sellf..."

            STANDALONE_DIR="$SELLF_DIR/admin-panel/.next/standalone/admin-panel"
            # WAŻNE: użyj --interpreter node, NIE 'node server.js' w cudzysłowach (bash nie dziedziczy env)
            RESTART_CMD="export PATH=\"\$HOME/.bun/bin:\$PATH\" && pm2 delete $PM2_NAME 2>/dev/null; cd $STANDALONE_DIR && unset HOSTNAME && set -a && source .env.local && set +a && export PORT=\${PORT:-3333} && export HOSTNAME=\${HOSTNAME:-::} && pm2 start server.js --name $PM2_NAME --interpreter node && pm2 save"

            if server_exec "$RESTART_CMD" 2>/dev/null; then
                echo -e "${GREEN}   ✅ Aplikacja zrestartowana${NC}"
            else
                echo -e "${YELLOW}   ⚠️  Restart nieudany - zrób ręcznie: pm2 restart $PM2_NAME${NC}"
            fi
        else
            echo -e "${YELLOW}   ⚠️  Nie znaleziono .env.local - Sellf nie zainstalowany?${NC}"
        fi
    fi

    # =============================================================================
    # 5. KONFIGURACJA CAPTCHA W SUPABASE AUTH
    # =============================================================================

    # Sprawdź czy mamy konfigurację Supabase
    SUPABASE_TOKEN_FILE="$HOME/.config/supabase/access_token"
    SELLF_CONFIG="$HOME/.config/sellf/supabase.env"

    if [ -f "$SUPABASE_TOKEN_FILE" ] && [ -f "$SELLF_CONFIG" ]; then
        echo ""
        echo "🔧 Konfiguruję CAPTCHA w Supabase Auth..."

        SUPABASE_TOKEN=$(cat "$SUPABASE_TOKEN_FILE")
        source "$SELLF_CONFIG"  # Ładuje PROJECT_REF

        if [ -n "$SUPABASE_TOKEN" ] && [ -n "$PROJECT_REF" ]; then
            CAPTCHA_CONFIG=$(cat <<EOF
{
    "security_captcha_enabled": true,
    "security_captcha_provider": "turnstile",
    "security_captcha_secret": "$SECRET_KEY"
}
EOF
)
            RESPONSE=$(curl -s -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
                -H "Authorization: Bearer $SUPABASE_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$CAPTCHA_CONFIG")

            if echo "$RESPONSE" | grep -q '"error"'; then
                echo -e "${YELLOW}   ⚠️  Nie udało się skonfigurować CAPTCHA w Supabase${NC}"
            else
                echo -e "${GREEN}   ✅ CAPTCHA włączony w Supabase Auth${NC}"
            fi
        fi
    else
        echo ""
        echo -e "${YELLOW}ℹ️  Aby włączyć CAPTCHA w Supabase, uruchom ponownie deploy.sh${NC}"
        echo "   lub skonfiguruj ręcznie w Supabase Dashboard → Authentication → Captcha"
    fi

    echo ""
    echo -e "${GREEN}🎉 Turnstile skonfigurowany!${NC}"
else
    ERROR=$(echo "$CREATE_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}❌ Błąd: $ERROR${NC}"
    echo ""
    echo "Pełna odpowiedź:"
    echo "$CREATE_RESPONSE" | head -c 500
    exit 1
fi
