#!/bin/bash

# Mikrus Toolbox - Cloudflare Optimization
# Ustawia optymalne ustawienia Cloudflare dla domen na Mikrus
# Author: Paweł (Lazy Engineer)
#
# Ustawienia:
#   - SSL: Flexible (Mikrus nie ma własnego certyfikatu)
#   - Brotli: ON
#   - Always HTTPS: ON
#   - Minimum TLS: 1.2
#   - Early Hints: ON
#   - Cache Rules: /_next/static/* (1 rok)
#   - Bypass Cache: /api/*

set -e

CONFIG_FILE="$HOME/.config/cloudflare/config"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Argumenty
FULL_DOMAIN="$1"

if [ -z "$FULL_DOMAIN" ]; then
    echo "Użycie: $0 <domena>"
    echo ""
    echo "Optymalizuje ustawienia Cloudflare dla domeny:"
    echo "  - SSL Flexible (wymagane dla Mikrus)"
    echo "  - Kompresja Brotli"
    echo "  - Always HTTPS"
    echo "  - Early Hints"
    echo "  - Cache Rules dla Next.js"
    echo ""
    echo "Przykład:"
    echo "  $0 app.mojadomena.pl"
    echo ""
    echo "Wymaga: ./local/setup-cloudflare.sh"
    exit 1
fi

# Sprawdź konfigurację
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Brak konfiguracji Cloudflare${NC}"
    echo "   Uruchom najpierw: ./local/setup-cloudflare.sh"
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}❌ Brak tokenu API${NC}"
    exit 1
fi

# Wyciągnij domenę główną (zone)
# app.example.com → example.com
ZONE_NAME=$(echo "$FULL_DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')

echo "☁️  Cloudflare Optimization"
echo "   Domena: $FULL_DOMAIN"
echo "   Zone: $ZONE_NAME"
echo ""

# Pobierz Zone ID
echo "🔍 Szukam Zone ID..."
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ZONE_ID" ]; then
    echo -e "${RED}❌ Nie znaleziono strefy: $ZONE_NAME${NC}"
    echo "   Upewnij się że domena jest dodana do Cloudflare"
    exit 1
fi

echo "   Zone ID: $ZONE_ID"
echo ""

# Funkcja do ustawiania opcji zone
set_zone_setting() {
    local SETTING="$1"
    local VALUE="$2"
    local DISPLAY_NAME="$3"

    echo -n "   $DISPLAY_NAME... "

    RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/$SETTING" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"value\":$VALUE}")

    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo -e "${GREEN}✅${NC}"
    else
        ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "${YELLOW}⚠️  $ERROR${NC}"
    fi
}

# =============================================================================
# USTAWIENIA ZONE
# =============================================================================

echo "⚙️  Ustawienia zone..."

# SSL Flexible - WYMAGANE dla Mikrus (brak certyfikatu na serwerze)
set_zone_setting "ssl" '"flexible"' "SSL Flexible"

# Brotli - lepsza kompresja
set_zone_setting "brotli" '"on"' "Brotli"

# Always HTTPS
set_zone_setting "always_use_https" '"on"' "Always HTTPS"

# Minimum TLS 1.2
set_zone_setting "min_tls_version" '"1.2"' "Min TLS 1.2"

# Early Hints - szybsze ładowanie
set_zone_setting "early_hints" '"on"' "Early Hints"

# HTTP/2
set_zone_setting "http2" '"on"' "HTTP/2"

# HTTP/3 (QUIC)
set_zone_setting "http3" '"on"' "HTTP/3"

echo ""

# =============================================================================
# CACHE RULES (dla Next.js)
# =============================================================================

echo "📦 Cache Rules..."

# Sprawdź czy ruleset już istnieje
RULESETS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets?phase=http_request_cache_settings" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

RULESET_ID=$(echo "$RULESETS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# Reguły cache
CACHE_RULES='{
  "rules": [
    {
      "expression": "(http.request.uri.path matches \"^/_next/static/.*\")",
      "description": "Cache Next.js static assets (1 year)",
      "action": "set_cache_settings",
      "action_parameters": {
        "edge_ttl": {
          "mode": "override_origin",
          "default": 31536000
        },
        "browser_ttl": {
          "mode": "override_origin",
          "default": 31536000
        }
      }
    },
    {
      "expression": "(http.request.uri.path matches \"^/api/.*\")",
      "description": "Bypass cache for API routes",
      "action": "set_cache_settings",
      "action_parameters": {
        "cache": false
      }
    }
  ]
}'

if [ -n "$RULESET_ID" ]; then
    # Aktualizuj istniejący ruleset
    echo -n "   Aktualizuję cache rules... "
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/$RULESET_ID" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$CACHE_RULES")
else
    # Utwórz nowy ruleset
    echo -n "   Tworzę cache rules... "
    FULL_RULESET=$(echo "$CACHE_RULES" | jq '. + {
        "name": "Mikrus Toolbox Cache Rules",
        "kind": "zone",
        "phase": "http_request_cache_settings"
    }')

    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$FULL_RULESET")
fi

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✅${NC}"
    echo "      /_next/static/* → cache 1 rok"
    echo "      /api/* → bypass cache"
else
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$ERROR" ]; then
        echo -e "${YELLOW}⚠️  $ERROR${NC}"
    else
        echo -e "${YELLOW}⚠️  Nie udało się (może brak uprawnień do Cache Rules)${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Optymalizacja zakończona!${NC}"
echo ""
echo "📋 Ustawione:"
echo "   • SSL: Flexible (wymagane dla Mikrus)"
echo "   • Kompresja: Brotli"
echo "   • HTTPS: wymuszony"
echo "   • TLS: minimum 1.2"
echo "   • HTTP/2 + HTTP/3"
echo "   • Early Hints"
echo "   • Cache: /_next/static/* (1 rok)"
echo "   • No-cache: /api/*"
echo ""
