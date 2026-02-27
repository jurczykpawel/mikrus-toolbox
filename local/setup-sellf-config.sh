#!/bin/bash

# Mikrus Toolbox - Sellf Configuration Setup
# Zbiera i zapisuje wszystkie klucze potrzebne do automatycznego deploymentu Sellf
# Author: Paweł (Lazy Engineer)
#
# Po uruchomieniu tego skryptu można odpalić:
#   ./local/deploy.sh sellf --ssh=ALIAS --yes
#
# Użycie:
#   ./local/setup-sellf-config.sh [--ssh=ALIAS]

set -e

# Załaduj biblioteki
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
source "$REPO_ROOT/lib/sellf-setup.sh"

# Parsuj argumenty
SSH_ALIAS=""
DOMAIN=""
DOMAIN_TYPE=""
SUPABASE_PROJECT=""
NO_SUPABASE=false
NO_STRIPE=false
NO_TURNSTILE=false

for arg in "$@"; do
    case "$arg" in
        --ssh=*) SSH_ALIAS="${arg#*=}" ;;
        --domain=*) DOMAIN="${arg#*=}" ;;
        --domain-type=*) DOMAIN_TYPE="${arg#*=}" ;;
        --supabase-project=*) SUPABASE_PROJECT="${arg#*=}" ;;
        --no-supabase) NO_SUPABASE=true ;;
        --no-stripe) NO_STRIPE=true ;;
        --no-turnstile) NO_TURNSTILE=true ;;
        --help|-h)
            cat <<EOF
Użycie: ./local/setup-sellf-config.sh [opcje]

Opcje:
  --ssh=ALIAS              SSH alias serwera
  --domain=DOMAIN          Domena (lub 'auto' dla automatycznej Cytrus)
  --domain-type=TYPE       Typ domeny: cytrus, cloudflare
  --supabase-project=REF   Project ref Supabase (pomija wybór interaktywny)
  --no-supabase            Bez konfiguracji Supabase
  --no-stripe              Bez konfiguracji Stripe
  --no-turnstile           Bez konfiguracji Turnstile

Przykłady:
  # Pełna interaktywna konfiguracja
  ./local/setup-sellf-config.sh

  # Z domeną i SSH
  ./local/setup-sellf-config.sh --ssh=mikrus --domain=auto --domain-type=cytrus

  # Z konkretnym projektem Supabase
  ./local/setup-sellf-config.sh --ssh=mikrus --supabase-project=abcdefghijk --domain=auto

  # Tylko Supabase (bez Stripe i Turnstile)
  ./local/setup-sellf-config.sh --no-stripe --no-turnstile
EOF
            exit 0
            ;;
    esac
done

# Walidacja domain-type
if [ -n "$DOMAIN_TYPE" ]; then
    case "$DOMAIN_TYPE" in
        cytrus|cloudflare) ;;
        *)
            echo -e "${RED}❌ Nieprawidłowy --domain-type: $DOMAIN_TYPE${NC}"
            echo "   Dozwolone: cytrus, cloudflare"
            exit 1
            ;;
    esac
fi

# Konwertuj --domain=auto na "-" (marker dla automatycznej Cytrus)
if [ "$DOMAIN" = "auto" ]; then
    DOMAIN="-"
    DOMAIN_TYPE="${DOMAIN_TYPE:-cytrus}"
fi

# Konfiguracja
CONFIG_FILE="$HOME/.config/sellf/deploy-config.env"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${BLUE}🔧 Sellf - Konfiguracja kluczy${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Ten skrypt zbierze wszystkie klucze potrzebne do deploymentu."
echo "Każdy krok jest opcjonalny - naciśnij Enter aby pominąć."
echo ""
echo "Po zakończeniu będziesz mógł uruchomić deployment automatycznie:"
echo -e "   ${BLUE}./local/deploy.sh sellf --ssh=ALIAS --yes${NC}"
echo ""

# =============================================================================
# 1. SSH ALIAS
# =============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "1️⃣  SSH - Serwer docelowy"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ -z "$SSH_ALIAS" ]; then
    echo "Dostępne aliasy SSH (z ~/.ssh/config):"
    grep -E "^Host " ~/.ssh/config 2>/dev/null | awk '{print "   • " $2}' | head -10
    echo ""
    read -p "SSH alias [Enter aby pominąć]: " SSH_ALIAS
fi

if [ -n "$SSH_ALIAS" ]; then
    echo -e "${GREEN}   ✅ SSH: $SSH_ALIAS${NC}"
else
    echo -e "${YELLOW}   ⏭️  Pominięto - podasz przy deployu${NC}"
fi

# =============================================================================
# 2. SUPABASE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "2️⃣  Supabase - Baza danych i Auth"
echo "════════════════════════════════════════════════════════════════"
echo ""

SUPABASE_CONFIGURED=false

if [ "$NO_SUPABASE" = true ]; then
    echo -e "${YELLOW}   ⏭️  Pominięto (--no-supabase)${NC}"
elif [ -n "$SUPABASE_PROJECT" ]; then
    # Podano project ref przez CLI - pobierz klucze automatycznie
    echo "   Projekt: $SUPABASE_PROJECT"

    # Upewnij się że mamy token
    if ! check_saved_supabase_token; then
        if ! supabase_manual_token_flow; then
            echo -e "${RED}   ❌ Brak tokena Supabase${NC}"
        fi
        if [ -n "$SUPABASE_TOKEN" ]; then
            save_supabase_token "$SUPABASE_TOKEN"
        fi
    fi

    if [ -n "$SUPABASE_TOKEN" ]; then
        if fetch_supabase_keys_by_ref "$SUPABASE_PROJECT"; then
            SUPABASE_CONFIGURED=true
            echo -e "${GREEN}   ✅ Supabase skonfigurowany${NC}"
        fi
    fi
else
    read -p "Skonfigurować Supabase teraz? [T/n]: " SETUP_SUPABASE
    if [[ ! "$SETUP_SUPABASE" =~ ^[Nn]$ ]]; then
        # Token
        if ! check_saved_supabase_token; then
            if ! supabase_login_flow; then
                echo -e "${YELLOW}   ⚠️  Logowanie nieudane, spróbuj ręcznie${NC}"
                supabase_manual_token_flow
            fi
            if [ -n "$SUPABASE_TOKEN" ]; then
                save_supabase_token "$SUPABASE_TOKEN"
            fi
        fi

        # Wybór projektu
        if [ -n "$SUPABASE_TOKEN" ]; then
            if select_supabase_project; then
                SUPABASE_CONFIGURED=true
                echo -e "${GREEN}   ✅ Supabase skonfigurowany${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}   ⏭️  Pominięto${NC}"
    fi
fi

# =============================================================================
# 3. STRIPE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "3️⃣  Stripe - Płatności"
echo "════════════════════════════════════════════════════════════════"
echo ""

STRIPE_PK="${STRIPE_PK:-}"
STRIPE_SK="${STRIPE_SK:-}"
STRIPE_WEBHOOK_SECRET="${STRIPE_WEBHOOK_SECRET:-}"

if [ "$NO_STRIPE" = true ]; then
    echo -e "${YELLOW}   ⏭️  Pominięto (--no-stripe)${NC}"
else
    read -p "Skonfigurować Stripe teraz? [T/n]: " SETUP_STRIPE
    if [[ ! "$SETUP_STRIPE" =~ ^[Nn]$ ]]; then
        echo ""
        echo "   Otwórz: https://dashboard.stripe.com/apikeys"
        echo ""
        read -p "STRIPE_PUBLISHABLE_KEY (pk_...): " STRIPE_PK

        if [ -n "$STRIPE_PK" ]; then
            read -p "STRIPE_SECRET_KEY (sk_...): " STRIPE_SK
            read -p "STRIPE_WEBHOOK_SECRET (whsec_..., opcjonalne): " STRIPE_WEBHOOK_SECRET
            echo -e "${GREEN}   ✅ Stripe skonfigurowany${NC}"
        else
            echo -e "${YELLOW}   ⏭️  Pominięto${NC}"
        fi
    else
        echo -e "${YELLOW}   ⏭️  Pominięto - skonfigurujesz w panelu Sellf${NC}"
    fi
fi

# =============================================================================
# 4. CLOUDFLARE TURNSTILE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "4️⃣  Cloudflare Turnstile - CAPTCHA (opcjonalne)"
echo "════════════════════════════════════════════════════════════════"
echo ""

TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}"
TURNSTILE_SECRET_KEY="${TURNSTILE_SECRET_KEY:-}"

if [ "$NO_TURNSTILE" = true ]; then
    echo -e "${YELLOW}   ⏭️  Pominięto (--no-turnstile)${NC}"
elif [[ "$SETUP_TURNSTILE" =~ ^[TtYy]$ ]] || { read -p "Skonfigurować Turnstile teraz? [t/N]: " SETUP_TURNSTILE; [[ "$SETUP_TURNSTILE" =~ ^[TtYy]$ ]]; }; then
    echo ""
    echo "   Turnstile możesz skonfigurować na dwa sposoby:"
    echo "   a) Automatycznie przez API (wymaga tokena Cloudflare)"
    echo "   b) Ręcznie - skopiuj klucze z dashboard"
    echo ""
    read -p "Użyć API Cloudflare? [T/n]: " USE_CF_API

    if [[ ! "$USE_CF_API" =~ ^[Nn]$ ]]; then
        # Sprawdź czy mamy token Cloudflare
        CF_TOKEN_FILE="$HOME/.config/cloudflare/api_token"
        if [ -f "$CF_TOKEN_FILE" ]; then
            echo "   🔑 Znaleziono zapisany token Cloudflare"
        else
            echo ""
            echo "   Potrzebujesz API Token z uprawnieniami:"
            echo "   • Account > Turnstile > Edit"
            echo ""
            echo "   Otwórz: https://dash.cloudflare.com/profile/api-tokens"
            echo ""
            read -p "Cloudflare API Token: " CF_API_TOKEN

            if [ -n "$CF_API_TOKEN" ]; then
                mkdir -p "$(dirname "$CF_TOKEN_FILE")"
                echo "$CF_API_TOKEN" > "$CF_TOKEN_FILE"
                chmod 600 "$CF_TOKEN_FILE"
            fi
        fi

        echo -e "${YELLOW}   ℹ️  Turnstile zostanie skonfigurowany podczas deploymentu${NC}"
        echo "   (wymaga znajomości domeny)"
    else
        echo ""
        echo "   Otwórz: https://dash.cloudflare.com/?to=/:account/turnstile"
        echo ""
        read -p "TURNSTILE_SITE_KEY: " TURNSTILE_SITE_KEY

        if [ -n "$TURNSTILE_SITE_KEY" ]; then
            read -p "TURNSTILE_SECRET_KEY: " TURNSTILE_SECRET_KEY
            echo -e "${GREEN}   ✅ Turnstile skonfigurowany${NC}"
        else
            echo -e "${YELLOW}   ⏭️  Pominięto${NC}"
        fi
    fi
else
    echo -e "${YELLOW}   ⏭️  Pominięto${NC}"
fi

# =============================================================================
# 5. DOMENA (opcjonalne)
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "5️⃣  Domena (opcjonalne)"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Jeśli DOMAIN podano przez CLI, pomiń pytania
if [ -n "$DOMAIN" ]; then
    if [ "$DOMAIN" = "-" ]; then
        echo -e "${GREEN}   ✅ Automatyczna domena Cytrus (--domain=auto)${NC}"
    else
        echo -e "${GREEN}   ✅ Domena: $DOMAIN ($DOMAIN_TYPE)${NC}"
    fi
else
    echo "   1) Automatyczna domena Cytrus (np. xyz123.byst.re)"
    echo "   2) Własna domena (wymaga konfiguracji DNS)"
    echo "   3) Pomiń - wybiorę podczas deploymentu"
    echo ""
    read -p "Wybierz [1-3, domyślnie 3]: " DOMAIN_CHOICE

    case "$DOMAIN_CHOICE" in
        1)
            DOMAIN="-"
            DOMAIN_TYPE="cytrus"
            echo -e "${GREEN}   ✅ Automatyczna domena Cytrus${NC}"
            ;;
        2)
            read -p "Podaj domenę (np. app.example.com): " DOMAIN
            if [ -n "$DOMAIN" ]; then
                echo "   Typ domeny:"
                echo "   a) Cytrus (subdomena *.byst.re, *.bieda.it, etc.)"
                echo "   b) Cloudflare (własna domena)"
                read -p "Wybierz [a/b]: " DTYPE
                if [[ "$DTYPE" =~ ^[Bb]$ ]]; then
                    DOMAIN_TYPE="cloudflare"
                else
                    DOMAIN_TYPE="cytrus"
                fi
                echo -e "${GREEN}   ✅ Domena: $DOMAIN ($DOMAIN_TYPE)${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}   ⏭️  Pominięto - wybierzesz podczas deploymentu${NC}"
            ;;
    esac
fi

# =============================================================================
# 6. ZAPISZ KONFIGURACJĘ
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "💾 Zapisuję konfigurację..."
echo "════════════════════════════════════════════════════════════════"
echo ""

mkdir -p "$(dirname "$CONFIG_FILE")"

cat > "$CONFIG_FILE" << EOF
# Sellf Deploy Configuration
# Wygenerowane przez setup-sellf-config.sh
# Data: $(date)

# SSH
SSH_ALIAS="$SSH_ALIAS"

# Supabase (klucze w osobnych plikach dla bezpieczeństwa)
SUPABASE_CONFIGURED=$SUPABASE_CONFIGURED
EOF

# Dodaj Supabase jeśli skonfigurowane
if [ "$SUPABASE_CONFIGURED" = true ]; then
    cat >> "$CONFIG_FILE" << EOF
SUPABASE_URL="$SUPABASE_URL"
PROJECT_REF="$PROJECT_REF"
SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
SUPABASE_SERVICE_KEY="$SUPABASE_SERVICE_KEY"
EOF
fi

# Dodaj Stripe jeśli podane
if [ -n "$STRIPE_PK" ]; then
    cat >> "$CONFIG_FILE" << EOF

# Stripe
STRIPE_PK="$STRIPE_PK"
STRIPE_SK="$STRIPE_SK"
STRIPE_WEBHOOK_SECRET="$STRIPE_WEBHOOK_SECRET"
EOF
fi

# Dodaj Turnstile jeśli podane ręcznie
if [ -n "$TURNSTILE_SITE_KEY" ]; then
    cat >> "$CONFIG_FILE" << EOF

# Cloudflare Turnstile
CLOUDFLARE_TURNSTILE_SITE_KEY="$TURNSTILE_SITE_KEY"
CLOUDFLARE_TURNSTILE_SECRET_KEY="$TURNSTILE_SECRET_KEY"
EOF
fi

# Dodaj domenę jeśli podana
if [ -n "$DOMAIN" ]; then
    cat >> "$CONFIG_FILE" << EOF

# Domena
DOMAIN="$DOMAIN"
DOMAIN_TYPE="$DOMAIN_TYPE"
EOF
fi

chmod 600 "$CONFIG_FILE"

echo -e "${GREEN}✅ Konfiguracja zapisana do:${NC}"
echo "   $CONFIG_FILE"
echo ""

# =============================================================================
# 7. PODSUMOWANIE
# =============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "📋 Podsumowanie"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Skonfigurowane:"
[ -n "$SSH_ALIAS" ] && echo -e "   ${GREEN}✅${NC} SSH: $SSH_ALIAS"
[ "$SUPABASE_CONFIGURED" = true ] && echo -e "   ${GREEN}✅${NC} Supabase: $PROJECT_REF"
[ -n "$STRIPE_PK" ] && echo -e "   ${GREEN}✅${NC} Stripe"
[ -n "$TURNSTILE_SITE_KEY" ] && echo -e "   ${GREEN}✅${NC} Turnstile"
[ -n "$DOMAIN" ] && echo -e "   ${GREEN}✅${NC} Domena: $DOMAIN"

echo ""
echo "Pominięte (można skonfigurować później):"
[ -z "$SSH_ALIAS" ] && echo -e "   ${YELLOW}⏭️${NC}  SSH"
[ "$SUPABASE_CONFIGURED" != true ] && echo -e "   ${YELLOW}⏭️${NC}  Supabase"
[ -z "$STRIPE_PK" ] && echo -e "   ${YELLOW}⏭️${NC}  Stripe (skonfigurujesz w panelu)"
[ -z "$TURNSTILE_SITE_KEY" ] && echo -e "   ${YELLOW}⏭️${NC}  Turnstile"
[ -z "$DOMAIN" ] && echo -e "   ${YELLOW}⏭️${NC}  Domena"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🚀 Następny krok - deployment"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ -n "$SSH_ALIAS" ] && [ "$SUPABASE_CONFIGURED" = true ]; then
    echo "Możesz teraz uruchomić deployment automatycznie:"
    echo ""
    echo -e "   ${BLUE}./local/deploy.sh sellf --ssh=$SSH_ALIAS --yes${NC}"
else
    echo "Uruchom deployment (odpowie na brakujące pytania):"
    echo ""
    if [ -n "$SSH_ALIAS" ]; then
        echo -e "   ${BLUE}./local/deploy.sh sellf --ssh=$SSH_ALIAS${NC}"
    else
        echo -e "   ${BLUE}./local/deploy.sh sellf --ssh=TWOJ_ALIAS${NC}"
    fi
fi
echo ""
