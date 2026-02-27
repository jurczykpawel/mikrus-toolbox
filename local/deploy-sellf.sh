#!/bin/bash

# Mikrus Toolbox - Sellf Deploy (prod + demo)
# Jedną komendą aktualizuje oba środowiska Sellf (Sellf) na serwerze.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/deploy-sellf.sh                  # deploy prod + demo z GitHub
#   ./local/deploy-sellf.sh --restart        # restart bez aktualizacji
#   ./local/deploy-sellf.sh --only-prod      # tylko prod
#   ./local/deploy-sellf.sh --only-demo      # tylko demo
#   ./local/deploy-sellf.sh --ssh=ALIAS      # inny serwer (domyślnie: mikrus)
#
# Środowiska:
#   prod  → sellf-tsa    /opt/stacks/sellf-tsa    port 3333
#   demo  → sellf-demo   /opt/stacks/sellf-demo   port 3334
#
# Pierwsze uruchomienie (migracja):
#   Skrypt automatycznie utworzy katalogi i skopiuje .env.local ze starych lokalizacji:
#   prod:  /scripts/docker-compose/sellf/admin-panel/.env.local
#   demo:  /opt/stacks/sellf-sellf/admin-panel/.env.local
#
# Wymagania:
#   - ~/.config/sellf/deploy-config.env (setup: ./local/setup-sellf-config.sh)
#   - SSH alias 'mikrus' w ~/.ssh/config

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY="$SCRIPT_DIR/deploy.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# KONFIGURACJA ŚRODOWISK
# =============================================================================

# prod
PROD_INSTANCE="sellf-tsa"
PROD_DIR="/opt/stacks/sellf-tsa"
PROD_PORT=3333
PROD_OLD_ENV="/scripts/docker-compose/sellf/admin-panel/.env.local"

# demo
DEMO_INSTANCE="sellf-demo"
DEMO_DIR="/opt/stacks/sellf-demo"
DEMO_PORT=3334
DEMO_OLD_ENV="/opt/stacks/sellf-sellf/admin-panel/.env.local"

# =============================================================================
# DOMYŚLNE WARTOŚCI
# =============================================================================

SSH_ALIAS="mikrus"
SKIP_PROD=false
SKIP_DEMO=false
RESTART_ONLY=false

# =============================================================================
# PARSOWANIE ARGUMENTÓW
# =============================================================================

for arg in "$@"; do
    case "$arg" in
        --ssh=*)     SSH_ALIAS="${arg#*=}" ;;
        --only-prod) SKIP_DEMO=true ;;
        --only-demo) SKIP_PROD=true ;;
        --restart)   RESTART_ONLY=true ;;
        --help|-h)
            cat <<EOF

Użycie: ./local/deploy-sellf.sh [opcje]

Opcje:
  --ssh=ALIAS   SSH alias z ~/.ssh/config (domyślnie: mikrus)
  --restart     Restart bez aktualizacji (np. po zmianie .env)
  --only-prod   Tylko prod (pomiń demo)
  --only-demo   Tylko demo (pomiń prod)
  --help        Ta pomoc

Środowiska:
  prod  →  PM2: sellf-tsa    port 3333
  demo  →  PM2: sellf-demo   port 3334

EOF
            exit 0
            ;;
        --*)
            echo -e "${RED}❌ Nieznana opcja: $arg${NC}" >&2
            echo "   Użyj --help aby zobaczyć dostępne opcje." >&2
            exit 1
            ;;
    esac
done

# =============================================================================
# WALIDACJA
# =============================================================================

if [ ! -f "$DEPLOY" ]; then
    echo -e "${RED}❌ Nie znaleziono deploy.sh: $DEPLOY${NC}"
    exit 1
fi

# =============================================================================
# MIGRACJA: utwórz katalog + skopiuj .env.local ze starej lokalizacji
# =============================================================================

migrate_if_needed() {
    local INSTANCE="$1"
    local TARGET_DIR="$2"
    local OLD_ENV="$3"

    # Sprawdź czy nowa lokalizacja już istnieje
    if ssh "$SSH_ALIAS" "[ -d '$TARGET_DIR/admin-panel' ]" 2>/dev/null; then
        return 0
    fi

    echo -e "  ${YELLOW}→ Nowa lokalizacja nie istnieje — przygotowuję $TARGET_DIR${NC}"

    # Utwórz katalog
    ssh "$SSH_ALIAS" "mkdir -p '$TARGET_DIR/admin-panel'"

    # Skopiuj .env.local ze starej lokalizacji
    if ssh "$SSH_ALIAS" "[ -f '$OLD_ENV' ]" 2>/dev/null; then
        ssh "$SSH_ALIAS" "cp '$OLD_ENV' '$TARGET_DIR/admin-panel/.env.local'"
        echo -e "  ${GREEN}→ Skopiowano .env.local z $OLD_ENV${NC}"
    else
        echo -e "  ${RED}❌ Brak $OLD_ENV${NC}"
        echo "     Utwórz ręcznie: $TARGET_DIR/admin-panel/.env.local"
        return 1
    fi
}

# =============================================================================
# NAGŁÓWEK
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
if [ "$RESTART_ONLY" = true ]; then
echo "║  🔄 Sellf Restart - prod + demo                               ║"
else
echo "║  🚀 Sellf Deploy - prod + demo                                ║"
fi
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  %-62s║\n" "Serwer:  $SSH_ALIAS"
printf "║  %-62s║\n" "Źródło:  GitHub (latest release)"
if [ "$SKIP_PROD" = true ]; then
printf "║  %-62s║\n" "Tryb:    tylko DEMO"
elif [ "$SKIP_DEMO" = true ]; then
printf "║  %-62s║\n" "Tryb:    tylko PROD"
fi
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# DEPLOY PROD
# =============================================================================

PROD_STATUS=0
DEMO_STATUS=0

if [ "$SKIP_PROD" = false ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}📦 PROD${NC}  $PROD_INSTANCE @ port $PROD_PORT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if migrate_if_needed "$PROD_INSTANCE" "$PROD_DIR" "$PROD_OLD_ENV"; then
        DEPLOY_ARGS="--ssh=$SSH_ALIAS --update --instance=$PROD_INSTANCE --yes"
        [ "$RESTART_ONLY" = true ] && DEPLOY_ARGS="$DEPLOY_ARGS --restart"

        if bash "$DEPLOY" sellf $DEPLOY_ARGS; then
            echo ""
            echo -e "${GREEN}✅ PROD gotowy${NC}"
        else
            PROD_STATUS=1
            echo ""
            echo -e "${RED}❌ PROD — błąd!${NC}"
        fi
    else
        PROD_STATUS=1
    fi
fi

# =============================================================================
# DEPLOY DEMO
# =============================================================================

if [ "$SKIP_DEMO" = false ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}🧪 DEMO${NC}  $DEMO_INSTANCE @ port $DEMO_PORT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if migrate_if_needed "$DEMO_INSTANCE" "$DEMO_DIR" "$DEMO_OLD_ENV"; then
        DEPLOY_ARGS="--ssh=$SSH_ALIAS --update --instance=$DEMO_INSTANCE --yes"
        [ "$RESTART_ONLY" = true ] && DEPLOY_ARGS="$DEPLOY_ARGS --restart"

        if bash "$DEPLOY" sellf $DEPLOY_ARGS; then
            echo ""
            echo -e "${GREEN}✅ DEMO gotowe${NC}"
        else
            DEMO_STATUS=1
            echo ""
            echo -e "${RED}❌ DEMO — błąd!${NC}"
        fi
    else
        DEMO_STATUS=1
    fi
fi

# =============================================================================
# PODSUMOWANIE
# =============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📋 Podsumowanie"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ "$SKIP_PROD" = false ]; then
    if [ $PROD_STATUS -eq 0 ]; then
        echo -e "  ${GREEN}✅ PROD${NC}  $PROD_INSTANCE (port $PROD_PORT)"
    else
        echo -e "  ${RED}❌ PROD${NC}  $PROD_INSTANCE — logi: ssh $SSH_ALIAS pm2 logs $PROD_INSTANCE"
    fi
fi

if [ "$SKIP_DEMO" = false ]; then
    if [ $DEMO_STATUS -eq 0 ]; then
        echo -e "  ${GREEN}✅ DEMO${NC}  $DEMO_INSTANCE (port $DEMO_PORT)"
    else
        echo -e "  ${RED}❌ DEMO${NC}  $DEMO_INSTANCE — logi: ssh $SSH_ALIAS pm2 logs $DEMO_INSTANCE"
    fi
fi

echo ""

if [ $PROD_STATUS -ne 0 ] || [ $DEMO_STATUS -ne 0 ]; then
    exit 1
fi
