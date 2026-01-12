# CLI Reference - Mikrus Toolbox

Pełna dokumentacja interfejsu wiersza poleceń dla Mikrus Toolbox.

## Spis treści

- [Przegląd](#przegląd)
- [Priorytet konfiguracji](#priorytet-konfiguracji)
- [deploy.sh - główny skrypt](#deploysh---główny-skrypt)
- [Opcje globalne](#opcje-globalne)
- [Konfiguracja bazy danych](#konfiguracja-bazy-danych)
- [Konfiguracja domeny](#konfiguracja-domeny)
- [Tryby pracy](#tryby-pracy)
- [Config file](#config-file)
- [Zmienne środowiskowe per aplikacja](#zmienne-środowiskowe-per-aplikacja)
- [Przykłady](#przykłady)

---

## Przegląd

Mikrus Toolbox obsługuje trzy tryby pracy:

1. **Interaktywny** - skrypt pyta o brakujące wartości
2. **Semi-automatyczny** - część wartości z CLI, reszta interaktywnie
3. **Pełna automatyzacja** - wszystkie wartości z CLI + `--yes`

```bash
# Interaktywny
./local/deploy.sh n8n --ssh=hanna

# Pełna automatyzacja
./local/deploy.sh n8n --ssh=hanna --db-source=shared --domain=auto --yes
```

---

## Priorytet konfiguracji

Wartości są pobierane w następującej kolejności (od najwyższego priorytetu):

```
1. Flagi CLI             --db-host=psql.example.com
2. Zmienne środowiskowe  DB_HOST=psql.example.com ./deploy.sh ...
3. Config file           ~/.config/mikrus/defaults.sh
4. Pytania interaktywne  (tylko gdy brak --yes)
```

---

## deploy.sh - główny skrypt

```bash
./local/deploy.sh APP [opcje]
```

### Argumenty

| Argument | Opis |
|----------|------|
| `APP` | Nazwa aplikacji (np. `n8n`, `uptime-kuma`) lub ścieżka do skryptu |

### Przykłady

```bash
# Po nazwie aplikacji
./local/deploy.sh n8n

# Po ścieżce
./local/deploy.sh apps/n8n/install.sh

# System script
./local/deploy.sh system/caddy-install.sh
```

---

## Opcje globalne

### SSH

| Flaga | Opis | Domyślnie |
|-------|------|-----------|
| `--ssh=ALIAS` | SSH alias z `~/.ssh/config` | `mikrus` |

```bash
./local/deploy.sh n8n --ssh=hanna
./local/deploy.sh n8n --ssh mikrus2
```

### Tryby pracy

| Flaga | Opis |
|-------|------|
| `--yes`, `-y` | Pomiń wszystkie potwierdzenia. Wymaga podania wszystkich wymaganych parametrów. |
| `--dry-run` | Pokaż co zostanie wykonane bez faktycznego wykonania. |
| `--help`, `-h` | Pokaż pomoc. |

---

## Konfiguracja bazy danych

Używane przez aplikacje wymagające PostgreSQL (n8n, listmonk, umami, nocodb, typebot).

### Flagi

| Flaga | Opis | Domyślnie |
|-------|------|-----------|
| `--db-source=TYPE` | `shared` (API Mikrus) lub `custom` | pytanie |
| `--db-host=HOST` | Host bazy danych | pytanie |
| `--db-port=PORT` | Port bazy | `5432` |
| `--db-name=NAME` | Nazwa bazy danych | pytanie |
| `--db-schema=SCHEMA` | Schema PostgreSQL | `public` |
| `--db-user=USER` | Użytkownik bazy | pytanie |
| `--db-pass=PASS` | Hasło bazy | pytanie |

### --db-source=shared

Pobiera dane bazy z API Mikrus. Wymaga zalogowania w przeglądarce.

```bash
./local/deploy.sh n8n --ssh=hanna --db-source=shared --domain=n8n.example.com --yes
```

**Uwaga:** Shared DB nie obsługuje rozszerzenia `pgcrypto`. Aplikacje wymagające `pgcrypto` (n8n, umami) potrzebują `--db-source=custom`.

### --db-source=custom

Ręczna konfiguracja bazy danych.

```bash
./local/deploy.sh n8n --ssh=hanna \
  --db-source=custom \
  --db-host=psql.example.com \
  --db-port=5432 \
  --db-name=n8n_db \
  --db-user=n8n_user \
  --db-pass=secretpassword \
  --domain=n8n.example.com \
  --yes
```

---

## Konfiguracja domeny

### Flagi

| Flaga | Opis | Domyślnie |
|-------|------|-----------|
| `--domain=DOMAIN` | Domena aplikacji lub `auto` | pytanie |
| `--domain-type=TYPE` | `cytrus`, `cloudflare`, `local` | pytanie |

### --domain-type=cytrus

Domena przydzielana przez system Cytrus (*.cytrus.app). Użyj `--domain=auto` dla automatycznego przydziału.

```bash
./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=cytrus --domain=auto --yes
```

### --domain-type=cloudflare

Własna domena zarządzana przez Cloudflare. Wymaga tunelu Cloudflare.

```bash
./local/deploy.sh n8n --ssh=hanna \
  --domain-type=cloudflare \
  --domain=n8n.mojafirma.pl \
  --yes
```

### --domain-type=local

Brak domeny. Dostęp przez tunel SSH.

```bash
./local/deploy.sh dockge --ssh=hanna --domain-type=local --yes
# Dostęp: ssh -L 5001:localhost:5001 hanna && http://localhost:5001
```

---

## Tryby pracy

### Tryb interaktywny (domyślny)

Skrypt pyta o brakujące wartości.

```bash
./local/deploy.sh n8n --ssh=hanna
# > Wybierz źródło bazy danych [shared/custom]: _
# > Podaj domenę: _
```

### Tryb --yes (automatyczny)

Wymaga wszystkich wartości. Brak wartości = błąd.

```bash
# OK - wszystkie wartości podane
./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=local --yes

# BŁĄD - brak wymaganych wartości
./local/deploy.sh n8n --ssh=hanna --yes
# > Błąd: --db-source jest wymagane w trybie --yes
```

### Tryb --dry-run

Pokazuje co zostanie wykonane bez faktycznego wykonania.

```bash
./local/deploy.sh n8n --ssh=hanna --dry-run
# [dry-run] Symulacja wykonania:
#   scp apps/n8n/install.sh hanna:/tmp/mikrus-deploy-123.sh
#   ssh -t hanna "export DB_HOST=... ; bash '/tmp/mikrus-deploy-123.sh'"
```

---

## Config file

Domyślne wartości można zapisać w `~/.config/mikrus/defaults.sh`:

```bash
# ~/.config/mikrus/defaults.sh

export DEFAULT_SSH="mikrus"
export DEFAULT_DB_PORT="5432"
export DEFAULT_DB_SCHEMA="public"
export DEFAULT_DOMAIN_TYPE="cytrus"
```

Dostępne zmienne:

| Zmienna | Opis |
|---------|------|
| `DEFAULT_SSH` | Domyślny SSH alias |
| `DEFAULT_DB_PORT` | Domyślny port bazy |
| `DEFAULT_DB_SCHEMA` | Domyślna schema PostgreSQL |
| `DEFAULT_DOMAIN_TYPE` | Domyślny typ domeny |

---

## Zmienne środowiskowe per aplikacja

Każda aplikacja akceptuje zmienne środowiskowe. Deploy.sh automatycznie je przekazuje.

### Aplikacje z bazą danych (PostgreSQL)

**n8n, listmonk, umami, nocodb, typebot**

```bash
DB_HOST=...     # Host bazy
DB_PORT=...     # Port (domyślnie 5432)
DB_NAME=...     # Nazwa bazy
DB_USER=...     # Użytkownik
DB_PASS=...     # Hasło
DB_SCHEMA=...   # Schema (domyślnie public)
DOMAIN=...      # Opcjonalna domena
```

### Redis

```bash
REDIS_PASS=...  # Hasło (auto-generowane jeśli brak)
```

### Vaultwarden

```bash
ADMIN_TOKEN=... # Token admina (auto-generowany jeśli brak)
DOMAIN=...      # Opcjonalna domena
```

### Cap (Loom alternative)

Wymaga MySQL + S3.

```bash
# Opcja 1: Zewnętrzna baza MySQL
DB_HOST=mysql.example.com
DB_PORT=3306
DB_NAME=cap
DB_USER=capuser
DB_PASS=secret

# Opcja 2: Lokalna baza MySQL
MYSQL_ROOT_PASS=rootsecret

# Opcja 1: Zewnętrzny S3
S3_ENDPOINT=https://xxx.r2.cloudflarestorage.com
S3_PUBLIC_URL=https://cdn.example.com
S3_REGION=auto
S3_BUCKET=cap-videos
S3_ACCESS_KEY=xxx
S3_SECRET_KEY=yyy

# Opcja 2: Lokalny MinIO
USE_LOCAL_MINIO=true

# Wymagane
DOMAIN=cap.example.com
```

### GateFlow

```bash
REPO_URL=https://github.com/...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_KEY=eyJ...
STRIPE_PK=pk_live_...
STRIPE_SK=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...  # opcjonalne
DOMAIN=app.gateflow.pl
```

### FileBrowser

```bash
DOMAIN=...         # Opcjonalna domena panelu admin
DOMAIN_PUBLIC=...  # Opcjonalna domena dla public hosting
PORT=...           # Port FileBrowser (domyślnie 8095)
PORT_PUBLIC=...    # Port static hosting (domyślnie 8096)
```

Przykłady instalacji:

```bash
# Cytrus - pełny setup (admin + public)
DOMAIN_PUBLIC=static.byst.re ./local/deploy.sh filebrowser \
  --ssh=mikrus --domain-type=cytrus --domain=files.byst.re --yes

# Cloudflare - pełny setup
DOMAIN_PUBLIC=static.example.com ./local/deploy.sh filebrowser \
  --ssh=mikrus --domain-type=cloudflare --domain=files.example.com --yes

# Tylko admin (bez public hosting)
./local/deploy.sh filebrowser --ssh=mikrus --domain-type=cytrus --domain=files.byst.re --yes

# Dodanie public hosting później
./local/add-static-hosting.sh static.byst.re mikrus
```

### Typebot

```bash
# Baza danych
DB_HOST=...
DB_PORT=...
DB_NAME=...
DB_USER=...
DB_PASS=...

# Domena (auto-generuje builder.DOMAIN i DOMAIN)
DOMAIN=typebot.example.com
```

### Proste aplikacje (tylko DOMAIN)

**uptime-kuma, ntfy, dockge, stirling-pdf, linkstack, cookie-hub, littlelink**

```bash
DOMAIN=...  # Opcjonalna domena
```

---

## Przykłady

### Pełna automatyzacja CI/CD

```bash
#!/bin/bash
# deploy-production.sh

./local/deploy.sh n8n \
  --ssh=production \
  --db-source=custom \
  --db-host=psql.production.internal \
  --db-port=5432 \
  --db-name=n8n_prod \
  --db-user=n8n \
  --db-pass="$N8N_DB_PASSWORD" \
  --domain-type=cloudflare \
  --domain=n8n.mojafirma.pl \
  --yes
```

### Szybki deploy z Cytrus

```bash
./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=cytrus --domain=auto --yes
```

### Deploy bez domeny (tunel SSH)

```bash
./local/deploy.sh dockge --ssh=hanna --domain-type=local --yes
# Dostęp: ssh -L 5001:localhost:5001 hanna
```

### Dry-run przed produkcją

```bash
./local/deploy.sh n8n \
  --ssh=production \
  --db-source=shared \
  --domain=n8n.mojafirma.pl \
  --dry-run
```

### Deploy z config file

```bash
# ~/.config/mikrus/defaults.sh
export DEFAULT_SSH="mojserwer"
export DEFAULT_DOMAIN_TYPE="cytrus"

# Teraz wystarczy:
./local/deploy.sh uptime-kuma --domain=auto --yes
```

---

## Kompatybilność platform

Mikrus Toolbox działa na:

| System | Status | Uwagi |
|--------|--------|-------|
| macOS | ✅ | Pełne wsparcie |
| Linux (Ubuntu, Debian, etc.) | ✅ | Pełne wsparcie |
| Windows + WSL2 | ✅ | Zalecane dla Windows |
| Windows + Git Bash | ⚠️ | Zobacz poniżej |

### Windows + Git Bash

Git Bash z domyślnym terminalem MinTTY ma problemy z interaktywnymi sesjami SSH. Skrypt automatycznie wykrywa to środowisko i pokazuje ostrzeżenie.

**Rozwiązania:**

1. **Windows Terminal (zalecane)** - uruchom Git Bash w Windows Terminal
2. **winpty** - prefix dla poleceń:
   ```bash
   winpty ./local/deploy.sh n8n --ssh=hanna
   ```
3. **Tryb automatyczny** - użyj `--yes` aby pominąć interakcje:
   ```bash
   ./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=local --yes
   ```
4. **WSL2 (najlepsze)** - zainstaluj Ubuntu z Microsoft Store

**Tryb `--yes` działa bez problemów** na Git Bash, ponieważ nie wymaga interaktywnych pytań.

---

## Rozwiązywanie problemów

### "Błąd: --db-source jest wymagane w trybie --yes"

W trybie `--yes` wszystkie wymagane wartości muszą być podane. Dodaj brakującą flagę lub usuń `--yes` dla trybu interaktywnego.

### Shared DB nie działa z n8n/umami

Shared DB nie obsługuje rozszerzenia `pgcrypto`. Użyj `--db-source=custom` z własną bazą PostgreSQL.

### Domena nie działa od razu

Po skonfigurowaniu domeny Cytrus, może minąć do 60 sekund zanim zacznie odpowiadać. Skrypt automatycznie czeka na propagację.

### SSH connection refused

Sprawdź czy alias SSH jest poprawnie skonfigurowany w `~/.ssh/config`:

```
Host hanna
    HostName srv00.mikr.us
    User root
    Port 10123
```
