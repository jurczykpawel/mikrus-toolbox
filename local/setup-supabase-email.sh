#!/bin/bash

# Mikrus Toolbox - Supabase Email Setup
# Konfiguruje SMTP i szablony email dla GateFlow
# Author: Paweł (Lazy Engineer)
#
# Używa Supabase Management API
#
# Użycie:
#   ./local/setup-supabase-email.sh

set -e

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguracja
CONFIG_DIR="$HOME/.config/gateflow"
SUPABASE_CONFIG="$CONFIG_DIR/supabase.env"
SUPABASE_TOKEN_FILE="$HOME/.config/supabase/access_token"

echo ""
echo -e "${BLUE}📧 Konfiguracja Email dla GateFlow${NC}"
echo ""

# =============================================================================
# 1. POBIERZ KONFIGURACJĘ SUPABASE
# =============================================================================

# Załaduj SUPABASE_URL
if [ -f "$SUPABASE_CONFIG" ]; then
    source "$SUPABASE_CONFIG"
fi

if [ -z "$SUPABASE_URL" ]; then
    echo -e "${RED}❌ Brak SUPABASE_URL${NC}"
    echo "   Najpierw uruchom instalację GateFlow"
    exit 1
fi

# Wyciągnij project ref
PROJECT_REF=$(echo "$SUPABASE_URL" | sed -E 's|https://([^.]+)\.supabase\.co.*|\1|')

if [ -z "$PROJECT_REF" ]; then
    echo -e "${RED}❌ Nie mogę wyciągnąć project ref z URL${NC}"
    exit 1
fi

echo "   Projekt: $PROJECT_REF"

# Pobierz token
if [ -f "$SUPABASE_TOKEN_FILE" ]; then
    SUPABASE_ACCESS_TOKEN=$(cat "$SUPABASE_TOKEN_FILE")
fi

if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Brak Personal Access Token${NC}"
    echo ""
    echo "Gdzie go znaleźć:"
    echo "   1. Otwórz: https://supabase.com/dashboard/account/tokens"
    echo "   2. Wygeneruj nowy token"
    echo ""

    read -p "Naciśnij Enter aby otworzyć Supabase..." _
    if command -v open &>/dev/null; then
        open "https://supabase.com/dashboard/account/tokens"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://supabase.com/dashboard/account/tokens"
    fi

    echo ""
    read -p "Wklej Personal Access Token: " SUPABASE_ACCESS_TOKEN

    if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
        echo -e "${RED}❌ Token jest wymagany${NC}"
        exit 1
    fi

    # Zapisz token
    mkdir -p "$(dirname "$SUPABASE_TOKEN_FILE")"
    echo "$SUPABASE_ACCESS_TOKEN" > "$SUPABASE_TOKEN_FILE"
    chmod 600 "$SUPABASE_TOKEN_FILE"
fi

# =============================================================================
# 2. POBIERZ AKTUALNĄ KONFIGURACJĘ
# =============================================================================

echo ""
echo "🔍 Pobieram aktualną konfigurację..."

CURRENT_CONFIG=$(curl -s -X GET "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H "Content-Type: application/json")

if echo "$CURRENT_CONFIG" | grep -q '"error"'; then
    echo -e "${RED}❌ Błąd API: $(echo "$CURRENT_CONFIG" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)${NC}"
    exit 1
fi

# Sprawdź czy SMTP jest już skonfigurowany
CURRENT_SMTP_HOST=$(echo "$CURRENT_CONFIG" | grep -o '"smtp_host":"[^"]*"' | cut -d'"' -f4)
if [ -n "$CURRENT_SMTP_HOST" ] && [ "$CURRENT_SMTP_HOST" != "null" ]; then
    echo -e "${GREEN}✅ SMTP już skonfigurowany: $CURRENT_SMTP_HOST${NC}"
    echo ""
    read -p "Chcesz zmienić konfigurację? [t/N]: " RECONFIGURE
    if [[ ! "$RECONFIGURE" =~ ^[TtYy]$ ]]; then
        echo "OK, zachowuję obecną konfigurację."
        exit 0
    fi
fi

# =============================================================================
# 3. KONFIGURACJA SMTP
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📮 KONFIGURACJA SMTP"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Popularne opcje SMTP:"
echo "   • Gmail: smtp.gmail.com (wymaga App Password)"
echo "   • Resend: smtp.resend.com"
echo "   • SendGrid: smtp.sendgrid.net"
echo "   • Własny serwer"
echo ""

read -p "SMTP Host (np. smtp.gmail.com): " SMTP_HOST

if [ -z "$SMTP_HOST" ]; then
    echo -e "${YELLOW}⏭️  Pominięto konfigurację SMTP${NC}"
else
    # Domyślny port dla popularnych providerów
    DEFAULT_PORT="587"
    if [[ "$SMTP_HOST" == *"gmail"* ]]; then
        DEFAULT_PORT="587"
    elif [[ "$SMTP_HOST" == *"resend"* ]]; then
        DEFAULT_PORT="465"
    fi

    read -p "SMTP Port [$DEFAULT_PORT]: " SMTP_PORT
    SMTP_PORT="${SMTP_PORT:-$DEFAULT_PORT}"

    read -p "SMTP Username (email): " SMTP_USER
    read -sp "SMTP Password: " SMTP_PASS
    echo ""

    read -p "Sender Email (np. noreply@twojadomena.pl): " SMTP_SENDER_EMAIL
    read -p "Sender Name (np. GateFlow): " SMTP_SENDER_NAME
    SMTP_SENDER_NAME="${SMTP_SENDER_NAME:-GateFlow}"

    CONFIGURE_SMTP=true
fi

# =============================================================================
# 4. SZABLON MAGIC LINK
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✨ SZABLON MAGIC LINK"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Możesz dostosować email z linkiem do logowania."
echo "Dostępne zmienne: {{ .Token }}, {{ .TokenHash }}, {{ .SiteURL }}, {{ .Email }}"
echo ""
read -p "Skonfigurować własny szablon magic link? [t/N]: " CONFIGURE_TEMPLATE

MAGIC_LINK_TEMPLATE=""
MAGIC_LINK_SUBJECT=""

if [[ "$CONFIGURE_TEMPLATE" =~ ^[TtYy]$ ]]; then
    echo ""
    read -p "Temat emaila [Twój link do logowania]: " MAGIC_LINK_SUBJECT
    MAGIC_LINK_SUBJECT="${MAGIC_LINK_SUBJECT:-Twój link do logowania}"

    echo ""
    echo "Szablon HTML (Enter dla domyślnego):"
    echo "Możesz też podać ścieżkę do pliku .html"
    echo ""
    read -p "Szablon lub ścieżka: " TEMPLATE_INPUT

    if [ -n "$TEMPLATE_INPUT" ]; then
        if [ -f "$TEMPLATE_INPUT" ]; then
            MAGIC_LINK_TEMPLATE=$(cat "$TEMPLATE_INPUT")
            echo "   ✅ Załadowano szablon z pliku"
        else
            MAGIC_LINK_TEMPLATE="$TEMPLATE_INPUT"
        fi
    else
        # Domyślny ładny szablon
        MAGIC_LINK_TEMPLATE='<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
    .button { display: inline-block; background: #4F46E5; color: white !important; text-decoration: none; padding: 12px 24px; border-radius: 6px; margin: 20px 0; }
    .footer { margin-top: 30px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <h2>Zaloguj się do GateFlow</h2>
  <p>Kliknij poniższy przycisk aby się zalogować:</p>
  <a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=magiclink" class="button">Zaloguj się</a>
  <p>Link wygasa za 1 godzinę.</p>
  <p>Jeśli nie prosiłeś o ten email, zignoruj go.</p>
  <div class="footer">
    <p>Ten email został wysłany automatycznie.</p>
  </div>
</body>
</html>'
        echo "   ✅ Użyto domyślnego szablonu"
    fi
fi

# =============================================================================
# 5. ZASTOSUJ KONFIGURACJĘ
# =============================================================================

echo ""
echo "🚀 Zapisuję konfigurację..."

# Buduj JSON payload
CONFIG_JSON="{"

if [ "$CONFIGURE_SMTP" = true ]; then
    CONFIG_JSON="$CONFIG_JSON\"smtp_host\":\"$SMTP_HOST\","
    CONFIG_JSON="$CONFIG_JSON\"smtp_port\":\"$SMTP_PORT\","
    CONFIG_JSON="$CONFIG_JSON\"smtp_user\":\"$SMTP_USER\","
    CONFIG_JSON="$CONFIG_JSON\"smtp_pass\":\"$SMTP_PASS\","
    CONFIG_JSON="$CONFIG_JSON\"smtp_admin_email\":\"$SMTP_SENDER_EMAIL\","
    CONFIG_JSON="$CONFIG_JSON\"smtp_sender_name\":\"$SMTP_SENDER_NAME\","
fi

if [ -n "$MAGIC_LINK_SUBJECT" ]; then
    CONFIG_JSON="$CONFIG_JSON\"mailer_subjects_magic_link\":\"$MAGIC_LINK_SUBJECT\","
fi

if [ -n "$MAGIC_LINK_TEMPLATE" ]; then
    # Escape template for JSON
    ESCAPED_TEMPLATE=$(echo "$MAGIC_LINK_TEMPLATE" | jq -Rs .)
    CONFIG_JSON="$CONFIG_JSON\"mailer_templates_magic_link_content\":$ESCAPED_TEMPLATE,"
fi

# Usuń trailing comma i zamknij JSON
CONFIG_JSON="${CONFIG_JSON%,}}"

if [ "$CONFIG_JSON" = "{}" ]; then
    echo -e "${YELLOW}⚠️  Nic do skonfigurowania${NC}"
    exit 0
fi

# Wyślij do API
RESPONSE=$(curl -s -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CONFIG_JSON")

if echo "$RESPONSE" | grep -q '"error"'; then
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}❌ Błąd: $ERROR${NC}"
    echo ""
    echo "Pełna odpowiedź:"
    echo "$RESPONSE" | head -c 500
    exit 1
fi

echo -e "${GREEN}✅ Konfiguracja zapisana!${NC}"

# =============================================================================
# 6. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}🎉 Email skonfigurowany!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ "$CONFIGURE_SMTP" = true ]; then
    echo "📮 SMTP:"
    echo "   Host: $SMTP_HOST:$SMTP_PORT"
    echo "   Sender: $SMTP_SENDER_NAME <$SMTP_SENDER_EMAIL>"
    echo ""
fi

if [ -n "$MAGIC_LINK_TEMPLATE" ]; then
    echo "✨ Magic Link:"
    echo "   Temat: $MAGIC_LINK_SUBJECT"
    echo "   Szablon: Własny HTML"
    echo ""
fi

echo "📋 Następne kroki:"
echo "   1. Przetestuj logowanie przez magic link w GateFlow"
echo "   2. Sprawdź folder spam jeśli email nie dochodzi"
echo ""

if [[ "$SMTP_HOST" == *"gmail"* ]]; then
    echo -e "${YELLOW}💡 Dla Gmail:${NC}"
    echo "   Użyj App Password zamiast zwykłego hasła:"
    echo "   https://myaccount.google.com/apppasswords"
    echo ""
fi
