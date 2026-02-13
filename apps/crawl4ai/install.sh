#!/bin/bash

# Mikrus Toolbox - Crawl4AI
# AI-powered web crawler and scraper with REST API.
# Extract structured data from any website using LLMs.
# https://github.com/unclecode/crawl4ai
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=2500  # unclecode/crawl4ai:latest (Chromium + Python + ML deps)
#
# ⚠️  UWAGA: Ta aplikacja wymaga minimum 2GB RAM (Mikrus 2.0+)!
#     Crawl4AI uruchamia headless Chromium do crawlowania stron.
#     Na Mikrus 1.0 (1GB RAM) może powodować zawieszenie serwera.

set -e

APP_NAME="crawl4ai"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8000}

echo "--- 🕷️ Crawl4AI Setup ---"
echo "AI-powered web crawler z REST API."
echo ""

# Sprawdź dostępny RAM - WYMAGANE minimum 2GB!
TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")

if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 1800 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ BŁĄD: Za mało RAM dla Crawl4AI!                          ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Twój serwer: ${TOTAL_RAM}MB RAM                             ║"
    echo "║  Wymagane:    2048MB RAM (Mikrus 2.0+)                       ║"
    echo "║                                                              ║"
    echo "║  Crawl4AI uruchamia headless Chromium (~1-1.5GB RAM).        ║"
    echo "║  Na Mikrus 1.0 zawiesza serwer!                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# Domain
if [ -n "$DOMAIN" ]; then
    echo "✅ Domena: $DOMAIN"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
fi

# Generuj API token
CRAWL4AI_API_TOKEN=$(openssl rand -hex 32)

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Zapisz token
echo "$CRAWL4AI_API_TOKEN" | sudo tee .api_token > /dev/null
sudo chmod 600 .api_token
echo "✅ API token wygenerowany i zapisany"

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  crawl4ai:
    image: unclecode/crawl4ai:latest
    restart: always
    ports:
      - "$PORT:11235"
    environment:
      - CRAWL4AI_API_TOKEN=$CRAWL4AI_API_TOKEN
    shm_size: "1g"
    deploy:
      resources:
        limits:
          memory: 1536M
EOF

sudo docker compose up -d

# Health check - Chromium potrzebuje dużo czasu na start
echo "⏳ Czekam na uruchomienie Crawl4AI (~60-90s, Chromium się ładuje)..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 90 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    for i in $(seq 1 9); do
        sleep 10
        if curl -sf "http://localhost:$PORT" > /dev/null 2>&1 || curl -sf "http://localhost:$PORT/health" > /dev/null 2>&1; then
            echo "✅ Crawl4AI działa (po $((i*10))s)"
            break
        fi
        echo "   ... $((i*10))s"
        if [ "$i" -eq 9 ]; then
            echo "❌ Kontener nie wystartował w 90s!"
            sudo docker compose logs --tail 30
            exit 1
        fi
    done
fi

echo ""
if [ -n "$DOMAIN" ]; then
    echo "🔗 API dostępne pod: https://$DOMAIN"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
fi
echo ""
echo "🔑 API Token: $CRAWL4AI_API_TOKEN"
echo "   Zapisany w: $STACK_DIR/.api_token"
echo ""
echo "📋 Przykład użycia:"
echo "   curl -X POST http://localhost:$PORT/crawl \\"
echo "     -H 'Authorization: Bearer $CRAWL4AI_API_TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"urls\": [\"https://example.com\"]}'"
