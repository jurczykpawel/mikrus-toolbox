#!/bin/bash

# Mikrus Toolbox - Supabase Setup for Sellf
# Konfiguruje Supabase i uruchamia migracje
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/setup-supabase-sellf.sh [ssh_alias]
#
# Przykłady:
#   ./local/setup-supabase-sellf.sh mikrus    # Konfiguracja + migracje na serwerze
#   ./local/setup-supabase-sellf.sh          # Tylko konfiguracja

set -e

SSH_ALIAS="${1:-}"
GITHUB_REPO="jurczykpawel/sellf"
MIGRATIONS_PATH="supabase/migrations"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguracja
CONFIG_DIR="$HOME/.config/sellf"
CONFIG_FILE="$CONFIG_DIR/supabase.env"

echo ""
echo -e "${BLUE}🗄️  Supabase Setup for Sellf${NC}"
echo ""

# =============================================================================
# 1. SPRAWDŹ ISTNIEJĄCĄ KONFIGURACJĘ
# =============================================================================

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ] && [ -n "$SUPABASE_SERVICE_KEY" ]; then
        echo -e "${GREEN}✅ Znaleziono zapisaną konfigurację Supabase${NC}"
        echo "   URL: $SUPABASE_URL"
        echo ""
        read -p "Użyć istniejącej konfiguracji? [T/n]: " USE_EXISTING
        if [[ ! "$USE_EXISTING" =~ ^[Nn]$ ]]; then
            echo ""
            echo -e "${GREEN}✅ Używam zapisanej konfiguracji${NC}"

            # Przejdź do migracji
            if [ -n "$SSH_ALIAS" ]; then
                echo ""
                read -p "Uruchomić migracje na serwerze $SSH_ALIAS? [T/n]: " RUN_MIGRATIONS
                if [[ ! "$RUN_MIGRATIONS" =~ ^[Nn]$ ]]; then
                    # Sprawdź DATABASE_URL
                    if [ -z "$DATABASE_URL" ]; then
                        echo ""
                        echo "Potrzebuję Database URL do uruchomienia migracji."
                        echo ""
                        echo "Gdzie go znaleźć:"
                        echo "   1. Otwórz: https://supabase.com/dashboard"
                        echo "   2. Wybierz projekt → Settings → Database"
                        echo "   3. Sekcja 'Connection string' → URI"
                        echo ""
                        read -p "Wklej Database URL (postgresql://...): " DATABASE_URL

                        if [ -n "$DATABASE_URL" ]; then
                            # Zapisz do konfiga
                            echo "DATABASE_URL='$DATABASE_URL'" >> "$CONFIG_FILE"
                            chmod 600 "$CONFIG_FILE"
                        fi
                    fi

                    if [ -n "$DATABASE_URL" ]; then
                        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
                        DATABASE_URL="$DATABASE_URL" "$SCRIPT_DIR/setup-supabase-migrations.sh" "$SSH_ALIAS"
                    fi
                fi
            fi

            echo ""
            echo -e "${GREEN}🎉 Supabase skonfigurowany!${NC}"
            echo ""
            echo "Zmienne do użycia w deploy.sh:"
            echo "   SUPABASE_URL='$SUPABASE_URL'"
            echo "   SUPABASE_ANON_KEY='$SUPABASE_ANON_KEY'"
            echo "   SUPABASE_SERVICE_KEY='$SUPABASE_SERVICE_KEY'"
            exit 0
        fi
    fi
fi

# =============================================================================
# 2. TWORZENIE PROJEKTU SUPABASE
# =============================================================================

echo "Sellf wymaga projektu Supabase (bezpłatny plan wystarczy)."
echo ""
echo "Jeśli nie masz jeszcze projektu, stwórz go teraz:"
echo "   1. Otwórz: https://supabase.com/dashboard"
echo "   2. Kliknij 'New Project'"
echo "   3. Wybierz organizację i region (np. Frankfurt)"
echo "   4. Wpisz nazwę (np. 'sellf')"
echo "   5. Wygeneruj silne hasło do bazy"
echo "   6. Kliknij 'Create new project'"
echo ""

read -p "Naciśnij Enter aby otworzyć Supabase..." _

if command -v open &>/dev/null; then
    open "https://supabase.com/dashboard"
elif command -v xdg-open &>/dev/null; then
    xdg-open "https://supabase.com/dashboard"
fi

# =============================================================================
# 3. POBIERZ KLUCZE API
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📋 KLUCZE API"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Znajdziesz je w: Project Settings → API"
echo ""

# SUPABASE_URL
echo "1. Project URL (np. https://xxxxx.supabase.co)"
read -p "   SUPABASE_URL: " SUPABASE_URL

if [ -z "$SUPABASE_URL" ]; then
    echo -e "${RED}❌ SUPABASE_URL jest wymagany${NC}"
    exit 1
fi

# Walidacja URL
if [[ ! "$SUPABASE_URL" =~ ^https://.*\.supabase\.co$ ]]; then
    echo -e "${YELLOW}⚠️  URL wygląda nietypowo (powinien być https://xxx.supabase.co)${NC}"
    read -p "   Kontynuować? [t/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[TtYy]$ ]]; then
        exit 1
    fi
fi

# ANON KEY
echo ""
echo "2. anon public (zaczyna się od eyJ...)"
read -p "   SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}❌ SUPABASE_ANON_KEY jest wymagany${NC}"
    exit 1
fi

# SERVICE KEY
echo ""
echo "3. service_role (też zaczyna się od eyJ..., UWAGA: to jest secret!)"
read -p "   SUPABASE_SERVICE_KEY: " SUPABASE_SERVICE_KEY

if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${RED}❌ SUPABASE_SERVICE_KEY jest wymagany${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Klucze API pobrane${NC}"

# =============================================================================
# 4. POBIERZ DATABASE URL (dla migracji)
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📋 DATABASE URL (dla migracji)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Znajdziesz go w: Project Settings → Database → Connection string → URI"
echo "(zaczyna się od postgresql://)"
echo ""
read -p "DATABASE_URL (lub Enter aby pominąć migracje): " DATABASE_URL

# =============================================================================
# 5. ZAPISZ KONFIGURACJĘ
# =============================================================================

echo ""
echo "💾 Zapisuję konfigurację..."

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
# Sellf - Supabase Configuration
# Wygenerowano: $(date)

SUPABASE_URL='$SUPABASE_URL'
SUPABASE_ANON_KEY='$SUPABASE_ANON_KEY'
SUPABASE_SERVICE_KEY='$SUPABASE_SERVICE_KEY'
EOF

if [ -n "$DATABASE_URL" ]; then
    echo "DATABASE_URL='$DATABASE_URL'" >> "$CONFIG_FILE"
fi

chmod 600 "$CONFIG_FILE"
echo -e "${GREEN}✅ Konfiguracja zapisana w $CONFIG_FILE${NC}"

# =============================================================================
# 6. URUCHOM MIGRACJE (opcjonalne)
# =============================================================================

if [ -n "$DATABASE_URL" ] && [ -n "$SSH_ALIAS" ]; then
    echo ""
    read -p "Uruchomić migracje na serwerze $SSH_ALIAS? [T/n]: " RUN_MIGRATIONS
    if [[ ! "$RUN_MIGRATIONS" =~ ^[Nn]$ ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        DATABASE_URL="$DATABASE_URL" "$SCRIPT_DIR/setup-supabase-migrations.sh" "$SSH_ALIAS"
    fi
elif [ -n "$DATABASE_URL" ]; then
    echo ""
    read -p "Uruchomić migracje lokalnie (wymaga Docker)? [T/n]: " RUN_MIGRATIONS
    if [[ ! "$RUN_MIGRATIONS" =~ ^[Nn]$ ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        DATABASE_URL="$DATABASE_URL" "$SCRIPT_DIR/setup-supabase-migrations.sh"
    fi
fi

# =============================================================================
# 7. PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}🎉 Supabase skonfigurowany!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Konfiguracja zapisana w: $CONFIG_FILE"
echo ""
echo "Użycie z deploy.sh:"
echo "   source ~/.config/sellf/supabase.env"
echo "   ./local/deploy.sh sellf --ssh=mikrus --domain=gf.example.com"
echo ""
echo "Lub ręcznie:"
echo "   SUPABASE_URL='$SUPABASE_URL' \\"
echo "   SUPABASE_ANON_KEY='$SUPABASE_ANON_KEY' \\"
echo "   SUPABASE_SERVICE_KEY='$SUPABASE_SERVICE_KEY' \\"
echo "   ./local/deploy.sh sellf --ssh=mikrus --domain=gf.example.com"
echo ""
