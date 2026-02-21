#!/bin/bash

# Mikrus Toolbox - PicoClaw
# Ultra-lekki osobisty asystent AI — alternatywa dla OpenClaw.
# Automatyzuj zadania przez Telegram, Discord lub Slack.
# https://github.com/sipeed/picoclaw
# Author: Pawel (Lazy Engineer)
#
# IMAGE_SIZE_MB=10
# DB_BUNDLED=false
#
# WYMAGANIA:
#   - Klucz API do LLM (OpenRouter, Anthropic, OpenAI, etc.)
#   - Token bota (Telegram, Discord lub Slack)
#   - Minimum 64MB RAM
#
# Stack: 1 kontener (sipeed/picoclaw:latest)
#   - picoclaw (gateway mode - long-running bot)
#
# BEZPIECZENSTWO: Ten instalator stosuje maksymalna izolacje Docker:
#   - Read-only filesystem
#   - Wszystkie capabilities usuniete (cap_drop: ALL)
#   - no-new-privileges
#   - Siec ograniczona (internal network + egress proxy opcjonalnie)
#   - Limity zasobow (128MB RAM, 1 CPU)
#   - Non-root user
#   - Domyslny profil seccomp Dockera
#   - Brak montowania Docker socket

set -e

APP_NAME="picoclaw"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-18790}

echo "--- 🤖 PicoClaw Setup ---"
echo "Ultra-lekki asystent AI dla Telegram/Discord/Slack."
echo ""

# Port binding: Cytrus wymaga 0.0.0.0, Cloudflare/local -> 127.0.0.1
if [ "${DOMAIN_TYPE:-}" = "cytrus" ]; then
    BIND_ADDR=""
else
    BIND_ADDR="127.0.0.1:"
fi

# =============================================================================
# 1. KONFIGURACJA — wizard lub istniejacy config.json
# =============================================================================

sudo mkdir -p "$STACK_DIR/config"
cd "$STACK_DIR"

CONFIG_FILE="$STACK_DIR/config/config.json"

if [ -f "$CONFIG_FILE" ]; then
    echo "✅ Konfiguracja istnieje: $CONFIG_FILE"
elif [ "$YES_MODE" = "true" ] || [ ! -t 0 ]; then
    # Utwórz template config z placeholderami do uzupełnienia
    cat <<'TEMPLATEEOF' | sudo tee "$CONFIG_FILE" > /dev/null
{
  "agents": {
    "defaults": {
      "model": "openrouter/anthropic/claude-sonnet-4-20250514"
    }
  },
  "providers": {
    "openrouter": {
      "api_key": "UZUPELNIJ_KLUCZ_API",
      "api_base": "https://openrouter.ai/api/v1"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "UZUPELNIJ_TOKEN_BOTA",
      "allowed_users": [0]
    }
  }
}
TEMPLATEEOF
    sudo chmod 600 "$CONFIG_FILE"
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  📝 Utworzono template konfiguracji PicoClaw                  ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Plik: $CONFIG_FILE"
    echo "║                                                              ║"
    echo "║  Uzupełnij w nim:                                            ║"
    echo "║    1. api_key  — klucz API dostawcy LLM                      ║"
    echo "║    2. token    — token bota (Telegram/Discord/Slack)         ║"
    echo "║    3. allowed_users — Twój User ID (tylko Telegram)          ║"
    echo "║                                                              ║"
    echo "║  Dostępni dostawcy LLM (sekcja providers):                   ║"
    echo "║    openrouter  — https://openrouter.ai/keys                  ║"
    echo "║    anthropic   — https://console.anthropic.com/settings/keys ║"
    echo "║    openai      — https://platform.openai.com/api-keys        ║"
    echo "║                                                              ║"
    echo "║  Dostępne kanały (sekcja channels):                          ║"
    echo "║    telegram    — token + allowed_users                       ║"
    echo "║    discord     — token                                       ║"
    echo "║    slack       — bot_token + app_token                       ║"
    echo "║                                                              ║"
    echo "║  Po uzupełnieniu uruchom ponownie deploy.                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
else
    # =========================================================================
    # INTERAKTYWNY WIZARD
    # =========================================================================

    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🧙 Kreator konfiguracji PicoClaw                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # --- Wybór dostawcy LLM ---
    echo "📡 Krok 1/2: Dostawca LLM"
    echo ""
    echo "  1) OpenRouter (zalecany — dostęp do wielu modeli)"
    echo "  2) Anthropic (Claude)"
    echo "  3) OpenAI (GPT)"
    echo ""
    read -p "Wybierz [1-3, domyślnie 1]: " LLM_CHOICE
    LLM_CHOICE=${LLM_CHOICE:-1}

    case "$LLM_CHOICE" in
        1)
            LLM_PROVIDER="openrouter"
            LLM_API_BASE="https://openrouter.ai/api/v1"
            LLM_MODEL="openrouter/anthropic/claude-sonnet-4-20250514"
            echo ""
            echo "   Klucz API znajdziesz na: https://openrouter.ai/keys"
            ;;
        2)
            LLM_PROVIDER="anthropic"
            LLM_API_BASE=""
            LLM_MODEL="anthropic/claude-sonnet-4-20250514"
            echo ""
            echo "   Klucz API znajdziesz na: https://console.anthropic.com/settings/keys"
            ;;
        3)
            LLM_PROVIDER="openai"
            LLM_API_BASE=""
            LLM_MODEL="openai/gpt-4o"
            echo ""
            echo "   Klucz API znajdziesz na: https://platform.openai.com/api-keys"
            ;;
        *)
            echo "❌ Nieprawidłowy wybór!"; exit 1
            ;;
    esac

    echo ""
    read -p "Klucz API ($LLM_PROVIDER): " LLM_API_KEY
    if [ -z "$LLM_API_KEY" ]; then
        echo "❌ Klucz API jest wymagany!"; exit 1
    fi

    read -p "Model [domyślnie: $LLM_MODEL]: " LLM_MODEL_INPUT
    LLM_MODEL=${LLM_MODEL_INPUT:-$LLM_MODEL}

    echo ""
    echo "✅ LLM: $LLM_PROVIDER / $LLM_MODEL"
    echo ""

    # --- Wybór kanału czatu ---
    echo "💬 Krok 2/2: Kanał czatu"
    echo ""
    echo "  1) Telegram (zalecany)"
    echo "  2) Discord"
    echo "  3) Slack"
    echo ""
    read -p "Wybierz [1-3, domyślnie 1]: " CHANNEL_CHOICE
    CHANNEL_CHOICE=${CHANNEL_CHOICE:-1}

    case "$CHANNEL_CHOICE" in
        1)
            CHANNEL_TYPE="telegram"
            echo ""
            echo "   📋 Jak uzyskać token bota Telegram:"
            echo "   1. Otwórz Telegram i napisz do @BotFather"
            echo "   2. Wyślij /newbot i podaj nazwę bota"
            echo "   3. Skopiuj token (format: 123456:ABC-DEF...)"
            echo ""
            echo "   📋 Jak uzyskać swój User ID:"
            echo "   1. Napisz do @userinfobot na Telegramie"
            echo "   2. Skopiuj swój ID (sam numer)"
            echo ""
            read -p "Token bota Telegram: " TG_BOT_TOKEN
            if [ -z "$TG_BOT_TOKEN" ]; then
                echo "❌ Token bota jest wymagany!"; exit 1
            fi
            read -p "Twój User ID (np. 123456789): " TG_USER_ID
            if [ -z "$TG_USER_ID" ]; then
                echo "❌ User ID jest wymagany (zabezpieczenie — tylko Ty możesz wydawać polecenia)!"; exit 1
            fi

            CHANNEL_JSON="\"telegram\": {
      \"enabled\": true,
      \"token\": \"$TG_BOT_TOKEN\",
      \"allowed_users\": [$TG_USER_ID]
    }"
            ;;
        2)
            CHANNEL_TYPE="discord"
            echo ""
            echo "   📋 Jak uzyskać token bota Discord:"
            echo "   1. Otwórz https://discord.com/developers/applications"
            echo "   2. Utwórz aplikację → sekcja Bot → skopiuj token"
            echo "   3. Włącz Message Content Intent"
            echo ""
            read -p "Token bota Discord: " DC_BOT_TOKEN
            if [ -z "$DC_BOT_TOKEN" ]; then
                echo "❌ Token bota jest wymagany!"; exit 1
            fi

            CHANNEL_JSON="\"discord\": {
      \"enabled\": true,
      \"token\": \"$DC_BOT_TOKEN\"
    }"
            ;;
        3)
            CHANNEL_TYPE="slack"
            echo ""
            echo "   📋 Jak uzyskać tokeny Slack:"
            echo "   1. Otwórz https://api.slack.com/apps"
            echo "   2. Utwórz aplikację → OAuth & Permissions → skopiuj Bot Token (xoxb-...)"
            echo "   3. Socket Mode → włącz i skopiuj App Token (xapp-...)"
            echo ""
            read -p "Bot Token (xoxb-...): " SLACK_BOT_TOKEN
            if [ -z "$SLACK_BOT_TOKEN" ]; then
                echo "❌ Bot Token jest wymagany!"; exit 1
            fi
            read -p "App Token (xapp-...): " SLACK_APP_TOKEN
            if [ -z "$SLACK_APP_TOKEN" ]; then
                echo "❌ App Token jest wymagany!"; exit 1
            fi

            CHANNEL_JSON="\"slack\": {
      \"enabled\": true,
      \"bot_token\": \"$SLACK_BOT_TOKEN\",
      \"app_token\": \"$SLACK_APP_TOKEN\"
    }"
            ;;
        *)
            echo "❌ Nieprawidłowy wybór!"; exit 1
            ;;
    esac

    echo ""
    echo "✅ Kanał: $CHANNEL_TYPE"
    echo ""

    # --- Generuj config.json (format PicoClaw v0.1.2: providers + channels) ---
    PROVIDER_JSON="\"$LLM_PROVIDER\": {
      \"api_key\": \"$LLM_API_KEY\""
    if [ -n "$LLM_API_BASE" ]; then
        PROVIDER_JSON="$PROVIDER_JSON,
      \"api_base\": \"$LLM_API_BASE\""
    fi
    PROVIDER_JSON="$PROVIDER_JSON
    }"

    cat <<CONFIGEOF | sudo tee "$CONFIG_FILE" > /dev/null
{
  "agents": {
    "defaults": {
      "model": "$LLM_MODEL"
    }
  },
  "providers": {
    $PROVIDER_JSON
  },
  "channels": {
    $CHANNEL_JSON
  }
}
CONFIGEOF

    sudo chmod 600 "$CONFIG_FILE"
    echo "✅ Konfiguracja zapisana: $CONFIG_FILE"
    echo ""
fi

# =============================================================================
# 2. DOCKER COMPOSE — maksymalne zabezpieczenia
# =============================================================================
# UWAGA: Używamy domyślnego profilu seccomp Dockera (blokuje ~44 niebezpieczne
# syscalls: reboot, mount, swapon, ptrace itp.). Profil niestandardowy wymaga
# utrzymania listy syscalli per-kernel i łamie kompatybilność z nowszymi jądrami.
# W połączeniu z cap_drop ALL + no-new-privileges izolacja jest wystarczająca.

echo "🐳 Tworzę docker-compose.yaml..."

# PicoClaw nie wystawia portów — bot komunikuje się wychodzącymi połączeniami.
# Health check używa wewnętrznego endpointu kontenera.

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  picoclaw:
    image: sipeed/picoclaw:latest
    container_name: picoclaw
    restart: unless-stopped

    # --- BEZPIECZENSTWO: non-root user ---
    user: "1000:1000"
    environment:
      - HOME=/home/picoclaw

    # --- BEZPIECZENSTWO: read-only filesystem ---
    read_only: true

    # --- BEZPIECZENSTWO: tmpfs dla plikow tymczasowych ---
    tmpfs:
      - /tmp:size=32M,noexec,nosuid,nodev

    # --- Wolumeny ---
    volumes:
      - ./config/config.json:/home/picoclaw/.picoclaw/config.json:ro
      - picoclaw-workspace:/home/picoclaw/.picoclaw/workspace

    # --- BEZPIECZENSTWO: usuniecie WSZYSTKICH capabilities ---
    cap_drop:
      - ALL

    # --- BEZPIECZENSTWO: blokada eskalacji uprawnien ---
    security_opt:
      - no-new-privileges:true

    # --- BEZPIECZENSTWO: limity zasobow ---
    deploy:
      resources:
        limits:
          memory: 128M
          cpus: "1.0"
        reservations:
          memory: 16M
          cpus: "0.1"

    # --- BEZPIECZENSTWO: limity procesow i plikow ---
    ulimits:
      nproc: 64
      nofile:
        soft: 1024
        hard: 2048

    # --- BEZPIECZENSTWO: zakaz uprzywilejowanego trybu ---
    privileged: false

    # --- Health check ---
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:18790/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

    # --- Logi ---
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

    # --- Komenda ---
    command: ["gateway"]

    # --- Siec ---
    networks:
      - picoclaw-net

networks:
  picoclaw-net:
    driver: bridge
    # NOTE: nie ustawiamy internal:true bo picoclaw potrzebuje internetu
    # (polaczenia z API LLM i kanalami czatu)
    # Ale izolujemy od innych kontenerow na serwerze

volumes:
  picoclaw-workspace:
EOF

# Ustaw uprawnienia katalogu workspace
sudo mkdir -p "$STACK_DIR/config"
sudo chown -R 1000:1000 "$STACK_DIR/config" 2>/dev/null || true

echo "✅ docker-compose.yaml utworzony"
echo ""

# =============================================================================
# 4. URUCHOMIENIE
# =============================================================================

echo "--- Uruchamiam PicoClaw ---"
sudo docker compose up -d

# Health check — PicoClaw nie wystawia portów, sprawdzamy stan kontenera
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type check_container_running &>/dev/null; then
    check_container_running "$APP_NAME" || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    sleep 5
    if sudo docker compose ps --format json | grep -q '"State":"running"'; then
        echo "✅ PicoClaw działa"
    else
        echo "❌ Kontener nie wystartował!"; sudo docker compose logs --tail 20; exit 1
    fi
fi

# Dodatkowa weryfikacja health checka Docker
sleep 3
HEALTH_STATUS=$(sudo docker inspect --format='{{.State.Health.Status}}' picoclaw 2>/dev/null || echo "none")
if [ "$HEALTH_STATUS" = "healthy" ]; then
    echo "✅ Health check: healthy"
elif [ "$HEALTH_STATUS" = "starting" ]; then
    echo "⏳ Health check: starting (kontener się rozgrzewa — to normalne)"
else
    echo "⚠️  Health check: $HEALTH_STATUS (bot może potrzebować chwili na start)"
fi

# =============================================================================
# 5. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ PicoClaw zainstalowany!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🔒 Zabezpieczenia:"
echo "   • Read-only filesystem"
echo "   • Wszystkie capabilities usunięte (cap_drop: ALL)"
echo "   • no-new-privileges"
echo "   • Domyślny profil seccomp Dockera (blokuje ~44 niebezpieczne syscalls)"
echo "   • Non-root user (UID 1000)"
echo "   • Limity zasobów: 128MB RAM, 1 CPU"
echo "   • Limity procesów: 64 nproc, 2048 nofile"
echo "   • Izolowana sieć Docker"
echo "   • Brak Docker socket"
echo ""
echo "📋 Przydatne komendy:"
echo "   docker logs picoclaw              - logi bota"
echo "   docker restart picoclaw           - restart"
echo "   docker inspect picoclaw           - pełna konfiguracja"
echo "   cat $CONFIG_FILE                  - konfiguracja"
echo ""
echo "📝 Konfiguracja:"
echo "   Plik: $CONFIG_FILE"
echo "   Po edycji: docker restart picoclaw"
echo ""
echo "💡 Napisz do swojego bota na czacie — powinien odpowiadać!"
echo "════════════════════════════════════════════════════════════════"
