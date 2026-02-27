#!/bin/bash

# Mikrus Toolbox - Domain Setup Helper
# Używany przez skrypty instalacyjne do konfiguracji domeny.
# Author: Paweł (Lazy Engineer)
#
# NOWY FLOW z CLI:
#   1. parse_args() + load_defaults()  - z cli-parser.sh
#   2. ask_domain()       - sprawdza flagi, pyta tylko gdy brak
#   3. configure_domain() - konfiguruje domenę (po uruchomieniu usługi!)
#
# Flagi CLI:
#   --domain-type=cytrus|cloudflare|local
#   --domain=DOMAIN (lub --domain=auto dla Cytrus automatyczny)
#
# Po wywołaniu dostępne zmienne:
#   $DOMAIN_TYPE  - "cytrus" | "cloudflare" | "local"
#   $DOMAIN       - pełna domena, "-" dla auto-cytrus, lub "" dla local

# Załaduj cli-parser jeśli nie załadowany
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! type ask_if_empty &>/dev/null; then
    source "$SCRIPT_DIR/cli-parser.sh"
fi

# Załaduj server-exec jeśli nie załadowany
if ! type is_on_server &>/dev/null; then
    source "$SCRIPT_DIR/server-exec.sh"
fi

CLOUDFLARE_CONFIG="$HOME/.config/cloudflare/config"

# Kolory (jeśli nie zdefiniowane przez cli-parser)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
NC="${NC:-\033[0m}"

# Zmienne eksportowane (nie resetuj jeśli już ustawione)
export DOMAIN="${DOMAIN:-}"
export DOMAIN_TYPE="${DOMAIN_TYPE:-}"

# =============================================================================
# FAZA 1: Zbieranie informacji (respektuje flagi CLI)
# =============================================================================

ask_domain() {
    local APP_NAME="$1"
    local PORT="$2"
    local SSH_ALIAS="${3:-${SSH_ALIAS:-mikrus}}"

    # Jeśli DOMAIN_TYPE już ustawione z CLI
    if [ -n "$DOMAIN_TYPE" ]; then
        # Walidacja wartości
        case "$DOMAIN_TYPE" in
            cytrus|cloudflare|local) ;;
            *)
                echo -e "${RED}Błąd: --domain-type musi być: cytrus, cloudflare lub local${NC}" >&2
                return 1
                ;;
        esac

        # local nie wymaga publicznej domeny, ale zachowaj DOMAIN jeśli podana
        # (install.sh może użyć domeny do nazewnictwa instancji, np. WordPress multi-instance)
        if [ "$DOMAIN_TYPE" = "local" ]; then
            if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "auto" ]; then
                export DOMAIN=""
            fi
            echo -e "${GREEN}✅ Tryb: tylko lokalnie (tunel SSH)${NC}"
            return 0
        fi

        # Cytrus z --domain=auto
        if [ "$DOMAIN_TYPE" = "cytrus" ] && [ "$DOMAIN" = "auto" ]; then
            export DOMAIN="-"  # marker dla automatycznej domeny
            echo -e "${GREEN}✅ Tryb: automatyczna domena Cytrus${NC}"
            return 0
        fi

        # Cytrus/Cloudflare wymaga DOMAIN
        if [ -z "$DOMAIN" ]; then
            if [ "$YES_MODE" = true ]; then
                echo -e "${RED}Błąd: --domain jest wymagane dla --domain-type=$DOMAIN_TYPE${NC}" >&2
                return 1
            fi
            # Tryb interaktywny - dopytaj
            if [ "$DOMAIN_TYPE" = "cytrus" ]; then
                ask_domain_cytrus "$APP_NAME"
            else
                ask_domain_cloudflare "$APP_NAME"
            fi
            return $?
        fi

        # Walidacja: dla Cloudflare sprawdź czy root domena jest w konfiguracji
        if [ "$DOMAIN_TYPE" = "cloudflare" ] && [ -f "$CLOUDFLARE_CONFIG" ]; then
            local CLI_ROOT=$(echo "$DOMAIN" | rev | cut -d. -f1-2 | rev)
            if ! grep -q "^${CLI_ROOT}=" "$CLOUDFLARE_CONFIG"; then
                local AVAILABLE=$(grep -v "^#" "$CLOUDFLARE_CONFIG" | grep -v "API_TOKEN" | grep "=" | cut -d= -f1 | tr '\n' ' ')
                echo -e "${RED}❌ Domena '$CLI_ROOT' — Twój token Cloudflare nie ma dostępu do tej domeny!${NC}" >&2
                echo "   Dostępne domeny: $AVAILABLE" >&2
                echo "   Jeśli chcesz dodać tę domenę, uruchom ponownie: ./local/setup-cloudflare.sh" >&2
                return 1
            fi
        fi

        echo -e "${GREEN}✅ Domena: $DOMAIN (typ: $DOMAIN_TYPE)${NC}"
        return 0
    fi

    # Tryb --yes bez --domain-type = błąd
    if [ "$YES_MODE" = true ]; then
        echo -e "${RED}Błąd: --domain-type jest wymagane w trybie --yes${NC}" >&2
        return 1
    fi

    # Tryb interaktywny
    echo ""
    echo "Jak chcesz uzyskać dostęp do aplikacji?"
    echo ""

    echo "  1) 🍊 Domena Mikrusa (Cytrus) - najszybsze!"
    echo "     Automatyczna domena *.byst.re / *.bieda.it / *.toadres.pl"
    echo "     ➜ Działa od razu, bez konfiguracji DNS"
    echo ""

    echo "  2) ☁️  Własna domena przez Cloudflare"
    echo "     Skrypt skonfiguruje DNS automatycznie"
    echo "     ➜ Wymaga: ./local/setup-cloudflare.sh"
    echo ""
    echo "  3) 🔒 Tylko lokalnie (tunel SSH)"
    echo "     Dostęp przez: ssh -L $PORT:localhost:$PORT $SSH_ALIAS"
    echo "     ➜ Bez domeny, idealne dla paneli admina"
    echo ""

    read -p "Wybierz opcję [1-3]: " DOMAIN_CHOICE

    case $DOMAIN_CHOICE in
        1)
            export DOMAIN_TYPE="cytrus"
            ask_domain_cytrus "$APP_NAME"
            return $?
            ;;
        2)
            export DOMAIN_TYPE="cloudflare"
            ask_domain_cloudflare "$APP_NAME"
            return $?
            ;;
        3)
            export DOMAIN_TYPE="local"
            export DOMAIN=""
            echo ""
            echo -e "${GREEN}✅ Wybrano: tylko lokalnie (tunel SSH)${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}❌ Nieprawidłowy wybór${NC}"
            return 1
            ;;
    esac
}

ask_domain_cytrus() {
    local APP_NAME="$1"

    # Jeśli DOMAIN już ustawione (z CLI)
    if [ -n "$DOMAIN" ]; then
        return 0
    fi

    echo ""
    echo "Dostępne domeny Mikrusa (darmowe):"
    echo "  1) Automatyczna (system nada np. xyz123.byst.re)"
    echo "  2) *.byst.re    - wpiszesz własną subdomenę"
    echo "  3) *.bieda.it   - wpiszesz własną subdomenę"
    echo "  4) *.toadres.pl - wpiszesz własną subdomenę"
    echo "  5) *.tojest.dev - wpiszesz własną subdomenę"
    echo ""

    read -p "Wybierz [1-5]: " CYTRUS_CHOICE

    case $CYTRUS_CHOICE in
        1)
            export DOMAIN="-"  # automatyczna
            echo ""
            echo -e "${GREEN}✅ Wybrano: automatyczna domena Cytrus${NC}"
            ;;
        2)
            read -p "Podaj subdomenę (bez .byst.re): " SUBDOMAIN
            [ -z "$SUBDOMAIN" ] && { echo -e "${RED}❌ Pusta subdomena${NC}"; return 1; }
            export DOMAIN="${SUBDOMAIN}.byst.re"
            echo ""
            echo -e "${GREEN}✅ Wybrano: $DOMAIN${NC}"
            ;;
        3)
            read -p "Podaj subdomenę (bez .bieda.it): " SUBDOMAIN
            [ -z "$SUBDOMAIN" ] && { echo -e "${RED}❌ Pusta subdomena${NC}"; return 1; }
            export DOMAIN="${SUBDOMAIN}.bieda.it"
            echo ""
            echo -e "${GREEN}✅ Wybrano: $DOMAIN${NC}"
            ;;
        4)
            read -p "Podaj subdomenę (bez .toadres.pl): " SUBDOMAIN
            [ -z "$SUBDOMAIN" ] && { echo -e "${RED}❌ Pusta subdomena${NC}"; return 1; }
            export DOMAIN="${SUBDOMAIN}.toadres.pl"
            echo ""
            echo -e "${GREEN}✅ Wybrano: $DOMAIN${NC}"
            ;;
        5)
            read -p "Podaj subdomenę (bez .tojest.dev): " SUBDOMAIN
            [ -z "$SUBDOMAIN" ] && { echo -e "${RED}❌ Pusta subdomena${NC}"; return 1; }
            export DOMAIN="${SUBDOMAIN}.tojest.dev"
            echo ""
            echo -e "${GREEN}✅ Wybrano: $DOMAIN${NC}"
            ;;
        *)
            echo -e "${RED}❌ Nieprawidłowy wybór${NC}"
            return 1
            ;;
    esac

    return 0
}

ask_domain_cloudflare() {
    local APP_NAME="$1"

    # Jeśli DOMAIN już ustawione (z CLI)
    if [ -n "$DOMAIN" ]; then
        return 0
    fi

    if [ ! -f "$CLOUDFLARE_CONFIG" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Cloudflare nie jest skonfigurowany!${NC}"
        echo "   Uruchom najpierw: ./local/setup-cloudflare.sh"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✅ Cloudflare skonfigurowany${NC}"
    echo ""

    # Pobierz listę domen (tylko prawdziwe domeny - bez spacji, z kropką)
    local DOMAINS=()
    while IFS= read -r line; do
        # Filtruj: musi zawierać kropkę, nie może zawierać spacji ani @
        if [[ "$line" == *.* ]] && [[ "$line" != *" "* ]] && [[ "$line" != *"@"* ]]; then
            DOMAINS+=("$line")
        fi
    done < <(grep -v "^#" "$CLOUDFLARE_CONFIG" | grep -v "API_TOKEN" | grep "=" | cut -d= -f1)

    local DOMAIN_COUNT=${#DOMAINS[@]}

    if [ "$DOMAIN_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ Brak skonfigurowanych domen w Cloudflare${NC}"
        return 1
    fi

    local FULL_DOMAIN=""

    # Jeśli ≤3 domeny, pokaż gotowe propozycje
    if [ "$DOMAIN_COUNT" -le 3 ]; then
        echo "Wybierz domenę dla $APP_NAME:"
        echo ""

        local i=1
        for domain in "${DOMAINS[@]}"; do
            echo "  $i) $APP_NAME.$domain"
            ((i++))
        done
        echo ""
        echo "  Lub wpisz własną domenę (np. $APP_NAME.mojadomena.pl)"
        echo ""

        read -p "Wybór [1-$DOMAIN_COUNT] lub domena: " CHOICE

        # Sprawdź czy to numer
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$DOMAIN_COUNT" ]; then
            local SELECTED_DOMAIN="${DOMAINS[$((CHOICE-1))]}"
            FULL_DOMAIN="$APP_NAME.$SELECTED_DOMAIN"
        elif [ -n "$CHOICE" ]; then
            # Traktuj jako domenę wpisaną ręcznie - waliduj root domenę
            FULL_DOMAIN="$CHOICE"
            local INPUT_ROOT=$(echo "$FULL_DOMAIN" | rev | cut -d. -f1-2 | rev)
            local DOMAIN_FOUND=false
            for domain in "${DOMAINS[@]}"; do
                if [ "$domain" = "$INPUT_ROOT" ]; then
                    DOMAIN_FOUND=true
                    break
                fi
            done
            if [ "$DOMAIN_FOUND" = false ]; then
                echo ""
                echo -e "${RED}❌ Domena '$INPUT_ROOT' — Twój token Cloudflare nie ma dostępu do tej domeny!${NC}"
                echo "   Dostępne domeny: ${DOMAINS[*]}"
                echo ""
                echo "   Jeśli chcesz dodać tę domenę, uruchom ponownie: ./local/setup-cloudflare.sh"
                return 1
            fi
        else
            echo -e "${RED}❌ Nie podano domeny${NC}"
            return 1
        fi
    else
        # Więcej niż 3 domeny - stary tryb
        echo "Dostępne domeny:"
        local i=1
        for domain in "${DOMAINS[@]}"; do
            echo "  $i) $domain"
            ((i++))
        done
        echo ""

        read -p "Podaj pełną domenę (np. $APP_NAME.twojadomena.pl): " FULL_DOMAIN
    fi

    if [ -z "$FULL_DOMAIN" ]; then
        echo -e "${RED}❌ Domena nie może być pusta${NC}"
        return 1
    fi

    # Walidacja: root domena musi być w konfiguracji Cloudflare
    local INPUT_ROOT=$(echo "$FULL_DOMAIN" | rev | cut -d. -f1-2 | rev)
    local DOMAIN_FOUND=false
    for domain in "${DOMAINS[@]}"; do
        if [ "$domain" = "$INPUT_ROOT" ]; then
            DOMAIN_FOUND=true
            break
        fi
    done
    if [ "$DOMAIN_FOUND" = false ]; then
        echo ""
        echo -e "${RED}❌ Domena '$INPUT_ROOT' — Twój token Cloudflare nie ma dostępu do tej domeny!${NC}"
        echo "   Dostępne domeny: ${DOMAINS[*]}"
        echo ""
        echo "   Jeśli chcesz dodać tę domenę, uruchom ponownie: ./local/setup-cloudflare.sh"
        return 1
    fi

    export DOMAIN="$FULL_DOMAIN"
    echo ""
    echo -e "${GREEN}✅ Wybrano: $DOMAIN${NC}"

    return 0
}

# =============================================================================
# HELPER: Podsumowanie konfiguracji domeny
# =============================================================================

show_domain_summary() {
    echo ""
    echo "📋 Konfiguracja domeny:"
    echo "   Typ:    $DOMAIN_TYPE"
    if [ "$DOMAIN_TYPE" = "local" ]; then
        echo "   Dostęp: tunel SSH"
    elif [ "$DOMAIN" = "-" ]; then
        echo "   Domena: (automatyczna Cytrus)"
    else
        echo "   Domena: $DOMAIN"
    fi
    echo ""
}

# =============================================================================
# FAZA 2: Konfiguracja domeny (po uruchomieniu usługi!)
# =============================================================================

configure_domain() {
    local PORT="$1"
    local SSH_ALIAS="${2:-${SSH_ALIAS:-mikrus}}"

    # Dry-run mode
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[dry-run] Konfiguruję domenę: $DOMAIN_TYPE / $DOMAIN${NC}"
        if [ "$DOMAIN_TYPE" = "cytrus" ] && [ "$DOMAIN" = "-" ]; then
            DOMAIN="[auto-assigned].byst.re"
            export DOMAIN
        fi
        return 0
    fi

    # Local - nic nie robimy
    if [ "$DOMAIN_TYPE" = "local" ]; then
        echo ""
        echo "📋 Dostęp przez tunel SSH:"
        echo -e "   ${BLUE}ssh -L $PORT:localhost:$PORT $SSH_ALIAS${NC}"
        echo "   Potem otwórz: http://localhost:$PORT"
        return 0
    fi

    # Cytrus - wywołaj API
    if [ "$DOMAIN_TYPE" = "cytrus" ]; then
        configure_domain_cytrus "$PORT" "$SSH_ALIAS"
        return $?
    fi

    # Cloudflare - skonfiguruj DNS
    if [ "$DOMAIN_TYPE" = "cloudflare" ]; then
        configure_domain_cloudflare "$PORT" "$SSH_ALIAS"
        return $?
    fi

    echo -e "${RED}❌ Nieznany typ domeny: $DOMAIN_TYPE${NC}"
    return 1
}

configure_domain_cytrus() {
    local PORT="$1"
    local SSH_ALIAS="$2"

    echo ""
    echo "🍊 Konfiguruję domenę przez Cytrus..."

    # WAŻNE: Cytrus wymaga stabilnie działającej usługi na porcie!
    # Jeśli usługa nie odpowiada stabilnie, Cytrus skonfiguruje domenę z https://[ipv6]:port co nie działa
    echo "   Sprawdzam czy usługa odpowiada na porcie $PORT..."

    local MAX_WAIT=60
    local WAITED=0
    local SUCCESS_COUNT=0
    local REQUIRED_SUCCESSES=3  # Wymagamy 3 udanych odpowiedzi pod rząd

    while [ "$WAITED" -lt "$MAX_WAIT" ]; do
        local SERVICE_CHECK=$(server_exec "curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:$PORT 2>/dev/null" || echo "000")
        if [ "$SERVICE_CHECK" -ge 200 ] && [ "$SERVICE_CHECK" -lt 500 ]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            if [ "$SUCCESS_COUNT" -ge "$REQUIRED_SUCCESSES" ]; then
                echo -e "\r   ${GREEN}✅ Usługa gotowa i stabilna (HTTP $SERVICE_CHECK)${NC}"
                break
            fi
            printf "\r   ⏳ Usługa odpowiada, sprawdzam stabilność... (%d/%d)" "$SUCCESS_COUNT" "$REQUIRED_SUCCESSES"
        else
            SUCCESS_COUNT=0  # Reset jeśli fail
            printf "\r   ⏳ Czekam na usługę... (%ds/%ds)        " "$WAITED" "$MAX_WAIT"
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done

    if [ "$SUCCESS_COUNT" -lt "$REQUIRED_SUCCESSES" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Usługa nie odpowiada stabilnie na porcie $PORT${NC}"
        echo "   Cytrus może nie działać poprawnie. Sprawdź logi kontenera."
    fi
    echo ""

    # Pobierz klucz API
    local API_KEY=$(server_exec 'cat /klucz_api 2>/dev/null' 2>/dev/null)
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}❌ Brak klucza API. Włącz API: https://mikr.us/panel/?a=api${NC}"
        return 1
    fi

    local HOSTNAME=$(server_exec 'hostname' 2>/dev/null)

    local RESPONSE=$(curl -s -X POST "https://api.mikr.us/domain" \
        -d "key=$API_KEY" \
        -d "srv=$HOSTNAME" \
        -d "domain=$DOMAIN" \
        -d "port=$PORT")

    # Sprawdź odpowiedź
    if echo "$RESPONSE" | grep -qi '"status".*gotowe\|"domain"'; then
        # Wyciągnij domenę z odpowiedzi jeśli była automatyczna
        local ASSIGNED=$(echo "$RESPONSE" | sed -n 's/.*"domain"\s*:\s*"\([^"]*\)".*/\1/p')
        if [ "$DOMAIN" = "-" ] && [ -n "$ASSIGNED" ]; then
            export DOMAIN="$ASSIGNED"
        fi
        echo -e "${GREEN}✅ Domena skonfigurowana: https://$DOMAIN${NC}"
        return 0

    elif echo "$RESPONSE" | grep -qiE "już istnieje|ju.*istnieje|niepoprawna nazwa domeny"; then
        # API zwraca "Niepoprawna nazwa domeny" gdy domena jest zajęta
        echo -e "${YELLOW}⚠️  Domena $DOMAIN jest zajęta lub nieprawidłowa!${NC}"
        echo "   Spróbuj inną nazwę, np.: ${DOMAIN%%.*}-2.${DOMAIN#*.}"
        return 1

    else
        echo -e "${RED}❌ Błąd Cytrus: $RESPONSE${NC}"
        return 1
    fi
}

configure_domain_cloudflare() {
    local PORT="$1"
    local SSH_ALIAS="$2"

    local REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    local DNS_SCRIPT="$REPO_ROOT/local/dns-add.sh"
    local OPTIMIZE_SCRIPT="$REPO_ROOT/local/setup-cloudflare-optimize.sh"

    echo ""
    echo "☁️  Konfiguruję DNS w Cloudflare..."

    local DNS_OK=false
    if [ -f "$DNS_SCRIPT" ]; then
        if bash "$DNS_SCRIPT" "$DOMAIN" "$SSH_ALIAS"; then
            echo -e "${GREEN}✅ DNS skonfigurowany: $DOMAIN${NC}"
            DNS_OK=true
        else
            # Sprawdź czy rekord już istnieje (dns-add.sh wychodzi z 0 gdy IP takie samo)
            # Więc exit ≠ 0 oznacza prawdziwy błąd
            echo -e "${RED}❌ Konfiguracja DNS nie powiodła się!${NC}"
            echo "   Sprawdź ręcznie: ./local/dns-add.sh $DOMAIN $SSH_ALIAS"
        fi
    else
        echo -e "${YELLOW}⚠️  Nie znaleziono dns-add.sh${NC}"
    fi

    # Optymalizacja ustawień Cloudflare (SSL Full, cache, kompresja)
    if [ -f "$OPTIMIZE_SCRIPT" ]; then
        echo ""
        # Mapuj APP_NAME na --app preset (jeśli znany)
        local CF_APP_FLAG=""
        case "${APP_NAME:-}" in
            wordpress) CF_APP_FLAG="--app=wordpress" ;;
            sellf)  CF_APP_FLAG="--app=nextjs" ;;
        esac
        bash "$OPTIMIZE_SCRIPT" "$DOMAIN" $CF_APP_FLAG || echo -e "${YELLOW}⚠️  Optymalizacja Cloudflare pominięta${NC}"
    fi

    # Konfiguruj Caddy na serwerze (nawet jeśli DNS nie wymagał zmian)
    echo ""
    echo "🔒 Konfiguruję HTTPS (Caddy)..."

    # Walidacja domeny (zapobieganie Caddyfile/shell injection)
    if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$ ]]; then
        echo -e "${RED}❌ Nieprawidłowa domena: $DOMAIN${NC}" >&2
        return 1
    fi

    local CADDY_OK=false

    # Upewnij się że Caddy + mikrus-expose jest na serwerze
    if ! server_exec "command -v mikrus-expose &>/dev/null" 2>/dev/null; then
        echo "   mikrus-expose nie znalezione — instaluję Caddy..."
        ensure_toolbox "$SSH_ALIAS"
        local CADDY_SCRIPT="$REPO_ROOT/system/caddy-install.sh"
        if [ -f "$CADDY_SCRIPT" ]; then
            server_exec "bash -s" < "$CADDY_SCRIPT" 2>&1 | tail -3
        else
            server_exec "bash -s" < <(curl -sL "https://raw.githubusercontent.com/jurczykpawel/mikrus-toolbox/main/system/caddy-install.sh") 2>&1 | tail -3
        fi
    fi

    # Sprawdź czy to static site (szukamy pliku /tmp/APP_webroot, nie domain_public_webroot)
    # domain_public_webroot jest dla DOMAIN_PUBLIC, obsługiwane osobno w deploy.sh
    local WEBROOT=$(server_exec "ls /tmp/*_webroot 2>/dev/null | grep -v domain_public_webroot | head -1 | xargs cat 2>/dev/null" 2>/dev/null)

    if [ -n "$WEBROOT" ]; then
        # Static site (littlelink, etc.) - użyj trybu file_server
        echo "   Wykryto static site: $WEBROOT"
        if server_exec "command -v mikrus-expose &>/dev/null && mikrus-expose '$DOMAIN' '$WEBROOT' static" 2>/dev/null; then
            echo -e "${GREEN}✅ HTTPS skonfigurowany (file_server)${NC}"
            CADDY_OK=true
            # Usuń marker (nie usuwaj domain_public_webroot!)
            server_exec "ls /tmp/*_webroot 2>/dev/null | grep -v domain_public_webroot | xargs rm -f" 2>/dev/null
        fi
    else
        # Docker app - użyj reverse_proxy
        if server_exec "command -v mikrus-expose &>/dev/null && mikrus-expose '$DOMAIN' '$PORT' proxy" 2>/dev/null; then
            echo -e "${GREEN}✅ HTTPS skonfigurowany (reverse_proxy)${NC}"
            CADDY_OK=true
        fi
    fi

    # Fallback: mikrus-expose mógł odmówić bo domena już jest w Caddyfile — to OK
    if [ "$CADDY_OK" = false ]; then
        if server_exec "grep -q '$DOMAIN' /etc/caddy/Caddyfile 2>/dev/null"; then
            echo -e "${GREEN}✅ HTTPS już skonfigurowany w Caddy${NC}"
            CADDY_OK=true
        fi
    fi

    if [ "$CADDY_OK" = false ]; then
        if server_exec "command -v mikrus-expose &>/dev/null" 2>/dev/null; then
            echo -e "${RED}❌ mikrus-expose nie mógł skonfigurować Caddy${NC}"
            echo "   Sprawdź ręcznie: ssh $SSH_ALIAS 'cat /etc/caddy/Caddyfile'"
        else
            echo -e "${RED}❌ Caddy / mikrus-expose nie zainstalowane na serwerze${NC}"
            echo "   Zainstaluj: ssh $SSH_ALIAS 'bash -s' < system/caddy-install.sh"
        fi
    fi

    # Upewnij się że Caddy działa
    if [ "$CADDY_OK" = true ]; then
        if ! server_exec "systemctl is-active --quiet caddy" 2>/dev/null; then
            echo "   Uruchamiam Caddy..."
            server_exec "systemctl start caddy && systemctl enable caddy 2>/dev/null" 2>/dev/null
        fi
    fi

    # Podsumowanie
    echo ""
    if [ "$DNS_OK" = true ] && [ "$CADDY_OK" = true ]; then
        echo -e "${GREEN}🎉 Domena skonfigurowana: https://$DOMAIN${NC}"
    elif [ "$CADDY_OK" = true ]; then
        echo -e "${YELLOW}⚠️  Caddy OK, ale DNS wymaga uwagi: https://$DOMAIN${NC}"
    elif [ "$DNS_OK" = true ]; then
        echo -e "${YELLOW}⚠️  DNS OK, ale Caddy wymaga konfiguracji${NC}"
    else
        echo -e "${RED}❌ Domena nie została skonfigurowana — DNS i Caddy wymagają uwagi${NC}"
        return 1
    fi

    return 0
}

# =============================================================================
# FAZA 3: Weryfikacja czy domena działa
# =============================================================================

wait_for_domain() {
    local TIMEOUT="${1:-60}"  # domyślnie 60 sekund

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ] || [ "$DOMAIN_TYPE" = "local" ]; then
        return 0
    fi

    # Dry-run mode
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[dry-run] Czekam na domenę: $DOMAIN${NC}"
        return 0
    fi

    echo ""
    echo "⏳ Czekam aż $DOMAIN zacznie odpowiadać..."

    local START_TIME=$(date +%s)
    local SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local SPINNER_IDX=0

    while true; do
        local CURRENT_TIME=$(date +%s)
        local ELAPSED=$((CURRENT_TIME - START_TIME))

        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            echo ""
            echo -e "${YELLOW}⚠️  Timeout - domena jeszcze nie odpowiada${NC}"
            echo ""

            # Diagnostyka DNS
            echo "🔍 Diagnostyka:"
            local DIG_RESULT=""
            if command -v dig &>/dev/null; then
                # Sprawdź A i AAAA (Cloudflare mode używa AAAA)
                DIG_RESULT=$(dig +short A "$DOMAIN" 2>/dev/null)
                if [ -z "$DIG_RESULT" ]; then
                    DIG_RESULT=$(dig +short AAAA "$DOMAIN" 2>/dev/null)
                fi
            elif command -v nslookup &>/dev/null; then
                DIG_RESULT=$(nslookup "$DOMAIN" 2>/dev/null | grep -A1 "Name:" | grep "Address" | awk '{print $2}')
            fi

            # Dla Cloudflare — sprawdź też czy rekord istnieje w API
            local CF_RECORD_OK=false
            if [ "$DOMAIN_TYPE" = "cloudflare" ] && [ -f "$CLOUDFLARE_CONFIG" ]; then
                local DIAG_TOKEN=$(grep "^API_TOKEN=" "$CLOUDFLARE_CONFIG" | cut -d= -f2)
                local DIAG_ROOT=$(echo "$DOMAIN" | rev | cut -d. -f1-2 | rev)
                local DIAG_ZONE=$(grep "^${DIAG_ROOT}=" "$CLOUDFLARE_CONFIG" | cut -d= -f2)
                if [ -n "$DIAG_TOKEN" ] && [ -n "$DIAG_ZONE" ]; then
                    local CF_CHECK=$(curl -s "https://api.cloudflare.com/client/v4/zones/$DIAG_ZONE/dns_records?name=$DOMAIN" \
                        -H "Authorization: Bearer $DIAG_TOKEN" 2>/dev/null)
                    if echo "$CF_CHECK" | grep -q "\"name\":\"$DOMAIN\""; then
                        CF_RECORD_OK=true
                        local CF_TYPE=$(echo "$CF_CHECK" | grep -o '"type":"[^"]*"' | head -1 | sed 's/"type":"//;s/"//')
                        local CF_CONTENT=$(echo "$CF_CHECK" | grep -o '"content":"[^"]*"' | head -1 | sed 's/"content":"//;s/"//')
                        local CF_PROXIED=$(echo "$CF_CHECK" | grep -o '"proxied":[a-z]*' | head -1 | sed 's/"proxied"://')
                        echo -e "   ${GREEN}✓ Cloudflare DNS: $CF_TYPE → $CF_CONTENT (proxy: $CF_PROXIED)${NC}"
                    fi
                fi
            fi

            if [ -n "$DIG_RESULT" ]; then
                echo -e "   ${GREEN}✓ DNS resolve: $DOMAIN → $DIG_RESULT${NC}"
                if [ "$DOMAIN_TYPE" = "cloudflare" ]; then
                    echo "   ℹ️  IP powyżej to Cloudflare edge (poprawne przy proxy ON)"
                fi
            elif [ "$CF_RECORD_OK" = true ]; then
                echo -e "   ${YELLOW}~ DNS: rekord istnieje w Cloudflare, ale jeszcze nie propaguje się${NC}"
                echo "   Poczekaj 2-5 minut i sprawdź: dig +short $DOMAIN"
            else
                echo -e "   ${RED}✗ DNS: brak rekordu — domena nie resolwuje się${NC}"
                echo "   Sprawdź: ./local/dns-add.sh $DOMAIN ${SSH_ALIAS:-mikrus}"
            fi

            # Sprawdź HTTP (tylko gdy DNS resolwuje)
            if [ -n "$DIG_RESULT" ]; then
                local DIAG_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$DOMAIN" 2>/dev/null || echo "000")
                if [ "$DIAG_HTTP" = "000" ]; then
                    echo -e "   ${RED}✗ HTTPS: brak połączenia — SSL może nie być gotowy${NC}"
                elif [ "$DIAG_HTTP" = "521" ] || [ "$DIAG_HTTP" = "522" ] || [ "$DIAG_HTTP" = "523" ]; then
                    echo -e "   ${RED}✗ HTTPS: HTTP $DIAG_HTTP — Cloudflare nie łączy się z serwerem (sprawdź Caddy)${NC}"
                elif [ "$DIAG_HTTP" -ge 500 ]; then
                    echo -e "   ${RED}✗ HTTPS: HTTP $DIAG_HTTP — błąd serwera${NC}"
                else
                    echo -e "   ${YELLOW}~ HTTPS: HTTP $DIAG_HTTP${NC}"
                fi
            fi

            echo ""
            echo "   Sprawdź za chwilę: https://$DOMAIN"
            # Timeout to tylko info diagnostyczne — deploy się udał, DNS się propaguje
            return 0
        fi

        # Sprawdź HTTP code i zawartość
        local HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$DOMAIN" 2>/dev/null || echo "000")
        local RESPONSE=$(curl -s --max-time 5 "https://$DOMAIN" 2>/dev/null || echo "")

        # Cytrus - sprawdź czy to nie placeholder I czy HTTP 2xx
        if [ "$DOMAIN_TYPE" = "cytrus" ]; then
            # Cytrus placeholder ma <title>CYTR.US</title>
            if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
                if [ -n "$RESPONSE" ] && ! echo "$RESPONSE" | grep -q "<title>CYTR.US</title>"; then
                    echo ""
                    echo -e "${GREEN}✅ Domena działa! (HTTP $HTTP_CODE)${NC}"
                    return 0
                fi
            fi
        else
            # Cloudflare - sprawdź HTTP 2xx-4xx (nie 5xx)
            if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
                echo ""
                echo -e "${GREEN}✅ Domena działa! (HTTP $HTTP_CODE)${NC}"
                return 0
            fi
        fi

        # Spinner
        local CHAR="${SPINNER:$SPINNER_IDX:1}"
        SPINNER_IDX=$(( (SPINNER_IDX + 1) % ${#SPINNER} ))
        printf "\r   %s Sprawdzam... (%ds/%ds)" "$CHAR" "$ELAPSED" "$TIMEOUT"

        sleep 3
    done
}

# =============================================================================
# STARY FLOW (kompatybilność wsteczna)
# =============================================================================

# Stara funkcja get_domain - teraz wywołuje nowe funkcje
get_domain() {
    local APP_NAME="$1"
    local PORT="$2"
    local SSH_ALIAS="${3:-${SSH_ALIAS:-mikrus}}"

    # Faza 1: zbierz wybór
    if ! ask_domain "$APP_NAME" "$PORT" "$SSH_ALIAS"; then
        return 1
    fi

    # Faza 2: skonfiguruj (stary flow robi to od razu)
    # UWAGA: W nowym flow configure_domain() jest wywoływane PO uruchomieniu usługi!
    if [ "$DOMAIN_TYPE" != "local" ]; then
        if ! configure_domain "$PORT" "$SSH_ALIAS"; then
            return 1
        fi
    fi

    return 0
}

# Stara funkcja setup_domain
setup_domain() {
    local APP_NAME="$1"
    local PORT="$2"
    local SSH_ALIAS="${3:-${SSH_ALIAS:-mikrus}}"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🌐 Konfiguracja domeny dla: $APP_NAME"
    echo "╚════════════════════════════════════════════════════════════════╝"

    get_domain "$APP_NAME" "$PORT" "$SSH_ALIAS"
    return $?
}

# Pomocnicze funkcje (dla kompatybilności)
get_domain_cytrus() {
    local APP_NAME="$1"
    local PORT="$2"
    local SSH_ALIAS="$3"

    export DOMAIN_TYPE="cytrus"
    if ask_domain_cytrus "$APP_NAME"; then
        configure_domain_cytrus "$PORT" "$SSH_ALIAS"
        return $?
    fi
    return 1
}

get_domain_cloudflare() {
    local APP_NAME="$1"
    local PORT="$2"
    local SSH_ALIAS="$3"

    export DOMAIN_TYPE="cloudflare"
    if ask_domain_cloudflare "$APP_NAME"; then
        configure_domain_cloudflare "$PORT" "$SSH_ALIAS"
        return $?
    fi
    return 1
}

setup_local_only() {
    local APP_NAME="$1"
    local PORT="$2"
    local SSH_ALIAS="$3"

    export DOMAIN_TYPE="local"
    export DOMAIN=""
    configure_domain "$PORT" "$SSH_ALIAS"
}

setup_cloudflare() {
    get_domain_cloudflare "$@"
}

setup_cytrus() {
    get_domain_cytrus "$@"
}

# Eksportuj funkcje
export -f ask_domain
export -f ask_domain_cytrus
export -f ask_domain_cloudflare
export -f show_domain_summary
export -f configure_domain
export -f configure_domain_cytrus
export -f configure_domain_cloudflare
export -f wait_for_domain
export -f get_domain
export -f get_domain_cytrus
export -f get_domain_cloudflare
export -f setup_domain
export -f setup_local_only
export -f setup_cloudflare
export -f setup_cytrus
