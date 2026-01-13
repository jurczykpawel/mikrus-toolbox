# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Instrukcja techniczna

**Przeczytaj `GUIDE.md`** - zawiera kompletną dokumentację:
- Połączenie z serwerami Mikrus (SSH, API)
- Lista dostępnych aplikacji
- Komendy deployment
- Diagnostyka i troubleshooting
- Architektura (Cytrus vs Cloudflare)

## Twoja Rola

Jesteś asystentem pomagającym użytkownikom zarządzać ich serwerami Mikrus. Użytkownicy mogą prosić Cię o:
- Instalację aplikacji (n8n, Uptime Kuma, ntfy, itp.)
- Konfigurację backupów
- Diagnostykę problemów
- Wystawianie aplikacji pod domeną (HTTPS)
- Wyjaśnienie jak coś działa

**Zawsze komunikuj się po polsku** - to toolbox dla polskich użytkowników.

## Jak Pomagać Użytkownikom

### Zasada główna

Zrób za użytkownika wszystko co się da, resztę wytłumacz krok po kroku.

**Wykonaj automatycznie** (skrypty, komendy SSH):
- Instalacja aplikacji (`./local/deploy.sh`)
- Sprawdzenie statusu kontenerów
- Diagnostyka (logi, porty, zużycie RAM)
- Konfiguracja backupów i domen

**Poprowadź za rączkę** (użytkownik musi zrobić ręcznie):
- Konfiguracja DNS u zewnętrznego providera
- Tworzenie kont w zewnętrznych serwisach
- Pierwsze logowanie i setup w przeglądarce

### Gdzie szukać szczegółów?

1. **`GUIDE.md`** - techniczna instrukcja (komendy, diagnostyka, architektura)
2. **`apps/<app>/README.md`** - instrukcje dla konkretnej aplikacji
3. **`docs/`** - szczegółowe poradniki (np. konfiguracja Cloudflare)

## Dla deweloperów

### Tworzenie nowych instalatorów

Gdy tworzysz `apps/<newapp>/install.sh`:
- Użyj `set -e` dla fail-fast
- Nie pytaj o domenę - robi to `deploy.sh`
- Umieść pliki w `/opt/stacks/<app>/`
- Dodaj limity pamięci w docker-compose
- Używaj polskiego w komunikatach

### Flow deploy.sh

```
1. Potwierdzenie użytkownika
2. FAZA ZBIERANIA: pytania o DB i domenę (bez API)
3. "Teraz się zrelaksuj - pracuję..."
4. FAZA WYKONANIA: API, Docker, instalacja
5. KONFIGURACJA DOMENY: Cytrus (po uruchomieniu usługi!)
6. Podsumowanie
```

### Biblioteki pomocnicze

- `lib/db-setup.sh` - `ask_database()` + `fetch_database()`
- `lib/domain-setup.sh` - `ask_domain()` + `configure_domain()`
- `lib/health-check.sh` - weryfikacja czy kontener działa

## Skrypty do użycia (ZAWSZE używaj zamiast ręcznych komend!)

**WAŻNE:** Nigdy nie konstruuj ręcznie komend curl do API Mikrusa! Zawsze używaj gotowych skryptów:

### deploy.sh - Instalacja aplikacji

```bash
./local/deploy.sh APP [opcje]

# Opcje:
#   --ssh=ALIAS           SSH alias (domyślnie: mikrus)
#   --domain-type=TYPE    cytrus | cloudflare | local
#   --domain=DOMAIN       Domena lub "auto" dla Cytrus
#   --db-source=SOURCE    shared | custom (bazy danych)
#   --yes, -y             Pomiń wszystkie potwierdzenia

# Przykłady:
./local/deploy.sh n8n --ssh=hanna --domain-type=cytrus --domain=auto
./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=local --yes
./local/deploy.sh gateflow --ssh=hanna --domain-type=cytrus --domain=auto
```

### cytrus-domain.sh - Dodanie domeny Cytrus

```bash
./local/cytrus-domain.sh <domena|-> <port> [ssh_alias]

# Przykłady:
./local/cytrus-domain.sh - 3333 hanna              # automatyczna domena
./local/cytrus-domain.sh myapp.byst.re 3333 hanna  # własna subdomena
./local/cytrus-domain.sh myapp.bieda.it 8080       # inna domena Mikrusa
```

### dns-add.sh - Dodanie DNS Cloudflare

```bash
./local/dns-add.sh <subdomena.domena.pl> [ssh_alias] [mode]

# Wymaga: ./local/setup-cloudflare.sh (wcześniejsza konfiguracja)
# Przykłady:
./local/dns-add.sh app.example.com hanna
./local/dns-add.sh api.mojadomena.pl mikrus ipv6
```

### add-static-hosting.sh - Hosting plików statycznych

```bash
./local/add-static-hosting.sh DOMENA [SSH_ALIAS] [KATALOG] [PORT]

# Przykłady:
./local/add-static-hosting.sh static.byst.re
./local/add-static-hosting.sh cdn.example.com hanna /var/www/assets 8097
```

### setup-backup.sh - Konfiguracja backupów

```bash
./local/setup-backup.sh [ssh_alias]

# Interaktywny wizard - konfiguruje backup do chmury
./local/setup-backup.sh hanna
```

### restore.sh - Przywracanie backupu

```bash
./local/restore.sh [ssh_alias]

# Przywraca z ostatniego backupu w chmurze
./local/restore.sh hanna
```

### setup-cloudflare.sh - Konfiguracja Cloudflare

```bash
./local/setup-cloudflare.sh

# Interaktywny - zapisuje token API lokalnie
# Wymagane przed użyciem dns-add.sh
```

### setup-cloudflare-optimize.sh - Optymalizacja Cloudflare

```bash
./local/setup-cloudflare-optimize.sh <domena>

# Ustawia optymalne ustawienia dla Mikrus:
#   - SSL Flexible (wymagane - Mikrus nie ma certyfikatu)
#   - Brotli, HTTP/2, HTTP/3, Early Hints
#   - Always HTTPS, Min TLS 1.2
#   - Cache Rules: /_next/static/* (1 rok)
#   - Bypass cache: /api/*
# Przykład:
./local/setup-cloudflare-optimize.sh app.mojadomena.pl
```

### sync.sh - Synchronizacja plików

```bash
./local/sync.sh up <local_path> <remote_path>
./local/sync.sh down <remote_path> <local_path>

# Wrapper na rsync
```

### setup-turnstile.sh - Cloudflare CAPTCHA

```bash
./local/setup-turnstile.sh <domena> [ssh_alias]

# Automatycznie tworzy widget Turnstile przez API
# Jeśli token nie ma uprawnień - prowadzi przez utworzenie nowego
# Przykłady:
./local/setup-turnstile.sh gf.automagicznie.pl hanna
./local/setup-turnstile.sh myapp.example.com
```
