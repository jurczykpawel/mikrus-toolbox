#!/bin/bash

# Mikrus Toolbox - Supabase SMTP Setup
# Konfiguruje SMTP dla wysyłki emaili w Sellf
# Author: Paweł (Lazy Engineer)
#
# UWAGA: Szablony email są konfigurowane automatycznie przez deploy.sh
# Ten skrypt służy tylko do konfiguracji SMTP (własnego serwera email)
#
# Używa Supabase Management API
#
# Użycie:
#   ./local/setup-supabase-email.sh

set -e

# Załaduj bibliotekę Supabase
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
source "$REPO_ROOT/lib/sellf-setup.sh"

echo ""
echo -e "${BLUE}📮 Konfiguracja SMTP dla Supabase${NC}"
echo ""

# =============================================================================
# 1. TOKEN SUPABASE
# =============================================================================

if ! check_saved_supabase_token; then
    if ! supabase_manual_token_flow; then
        echo -e "${RED}❌ Nie udało się uzyskać tokena${NC}"
        exit 1
    fi
    save_supabase_token "$SUPABASE_TOKEN"
fi

# =============================================================================
# 2. WYBÓR PROJEKTU SUPABASE
# =============================================================================

if ! select_supabase_project; then
    echo -e "${RED}❌ Nie udało się wybrać projektu${NC}"
    exit 1
fi

# Użyj SUPABASE_TOKEN zamiast SUPABASE_ACCESS_TOKEN (kompatybilność z resztą skryptu)
SUPABASE_ACCESS_TOKEN="$SUPABASE_TOKEN"

# =============================================================================
# 3. KONFIGURACJA SMTP
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📮 KONFIGURACJA SMTP"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Popularne opcje:"
echo "   • Gmail: smtp.gmail.com (wymaga App Password)"
echo "   • Resend: smtp.resend.com"
echo "   • SendGrid: smtp.sendgrid.net"
echo ""

read -p "SMTP Host: " SMTP_HOST

if [ -z "$SMTP_HOST" ]; then
    echo -e "${YELLOW}⚠️  Anulowano${NC}"
    exit 0
fi

# Domyślny port
DEFAULT_PORT="587"
if [[ "$SMTP_HOST" == *"resend"* ]]; then
    DEFAULT_PORT="465"
fi

read -p "SMTP Port [$DEFAULT_PORT]: " SMTP_PORT
SMTP_PORT="${SMTP_PORT:-$DEFAULT_PORT}"

read -p "SMTP Username (email): " SMTP_USER
read -sp "SMTP Password: " SMTP_PASS
echo ""

read -p "Adres nadawcy (np. noreply@twojadomena.pl): " SMTP_SENDER_EMAIL
read -p "Nazwa nadawcy [Sellf]: " SMTP_SENDER_NAME
SMTP_SENDER_NAME="${SMTP_SENDER_NAME:-Sellf}"

# =============================================================================
# 4. ZAPISZ KONFIGURACJĘ
# =============================================================================

echo ""
echo "🚀 Zapisuję konfigurację SMTP w Supabase..."

# Buduj JSON payload
CONFIG_JSON=$(jq -n \
    --arg host "$SMTP_HOST" \
    --arg port "$SMTP_PORT" \
    --arg user "$SMTP_USER" \
    --arg pass "$SMTP_PASS" \
    --arg email "$SMTP_SENDER_EMAIL" \
    --arg name "$SMTP_SENDER_NAME" \
    '{
        smtp_host: $host,
        smtp_port: $port,
        smtp_user: $user,
        smtp_pass: $pass,
        smtp_admin_email: $email,
        smtp_sender_name: $name
    }')

# Wyślij do API
RESPONSE=$(curl -s -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CONFIG_JSON")

if echo "$RESPONSE" | grep -q '"error"'; then
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}❌ Błąd: $ERROR${NC}"
    exit 1
fi

# =============================================================================
# 5. PODSUMOWANIE
# =============================================================================

echo ""
echo -e "${GREEN}✅ SMTP skonfigurowany!${NC}"
echo ""
echo "📮 Ustawienia:"
echo "   Host: $SMTP_HOST:$SMTP_PORT"
echo "   Nadawca: $SMTP_SENDER_NAME <$SMTP_SENDER_EMAIL>"
echo ""

if [[ "$SMTP_HOST" == *"gmail"* ]]; then
    echo -e "${YELLOW}💡 Dla Gmail użyj App Password:${NC}"
    echo "   https://myaccount.google.com/apppasswords"
    echo ""
fi

echo "Emaile będą wysyłane przez Twój serwer SMTP zamiast domyślnego Supabase."
echo ""
