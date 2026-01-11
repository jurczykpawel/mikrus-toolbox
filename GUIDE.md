# Mikrus Toolbox - Instrukcja dla agentów AI

Ten dokument zawiera wszystkie informacje potrzebne do pracy z Mikrus Toolbox.
Przeznaczony dla agentów AI (Claude, GPT, Gemini, etc.) oraz ludzi.

## Spis treści

1. [Połączenie z serwerem](#połączenie-z-serwerem)
2. [Dostępne aplikacje](#dostępne-aplikacje)
3. [Komendy deployment](#komendy-deployment)
4. [Backup i restore](#backup-i-restore)
5. [Diagnostyka i troubleshooting](#diagnostyka-i-troubleshooting)
6. [Brakujące narzędzia](#brakujące-narzędzia)
7. [Architektura](#architektura)
8. [Limity i ograniczenia](#limity-i-ograniczenia)

---

## Połączenie z serwerem

### SSH Alias

Serwery Mikrus są dostępne przez SSH. Alias jest skonfigurowany w `~/.ssh/config`:

```bash
# Sprawdź dostępne aliasy
grep "^Host " ~/.ssh/config

# Typowe aliasy: mikrus, hanna, srv42, etc.
```

### Weryfikacja połączenia

```bash
# Test połączenia
ssh mikrus 'echo "OK: $(hostname)"'

# Sprawdź informacje o serwerze
ssh mikrus 'hostname && cat /etc/os-release | head -2'
```

### Klucz API Mikrusa

Klucz API znajduje się na serwerze w `/klucz_api`:

```bash
# Pobierz klucz API
ssh mikrus 'cat /klucz_api'

# Klucz jest wymagany do:
# - API bazy danych (https://api.mikr.us/db.bash)
# - API domen Cytrus (https://api.mikr.us/domain)
```

Jeśli klucz nie istnieje, użytkownik musi włączyć API w panelu:
https://mikr.us/panel/?a=api

---

## Dostępne aplikacje

Aplikacje znajdują się w `apps/<nazwa>/install.sh`:

| Aplikacja | Opis | Baza danych | Port |
|-----------|------|-------------|------|
| **uptime-kuma** | Monitoring usług (jak UptimeRobot) | - | 3001 |
| **ntfy** | Powiadomienia push | - | 8080 |
| **filebrowser** | Menedżer plików web | - | 8080 |
| **dockge** | UI do zarządzania Docker Compose | - | 5001 |
| **stirling-pdf** | Narzędzia PDF online | - | 8080 |
| **n8n** | Automatyzacja workflow | PostgreSQL | 5678 |
| **umami** | Web analytics (alt. Google Analytics) | PostgreSQL* | 3000 |
| **nocodb** | Baza danych (alt. Airtable) | PostgreSQL | 8080 |
| **listmonk** | Newsletter i mailing | PostgreSQL | 9000 |
| **typebot** | Kreator chatbotów | PostgreSQL | 3000 |
| **vaultwarden** | Menedżer haseł (Bitwarden) | SQLite | 8080 |
| **linkstack** | Strona z linkami (alt. Linktree) | SQLite | 8080 |
| **redis** | Cache/baza klucz-wartość | - | 6379 |

*umami wymaga PostgreSQL z rozszerzeniem `pgcrypto` - NIE działa ze współdzieloną bazą Mikrusa!

---

## Komendy deployment

### Główny skrypt: `deploy.sh`

```bash
# Instalacja aplikacji (Smart Mode)
./local/deploy.sh <app_name> [ssh_alias]

# Przykłady:
./local/deploy.sh n8n              # na domyślnym serwerze 'mikrus'
./local/deploy.sh uptime-kuma hanna  # na serwerze 'hanna'

# Uruchomienie dowolnego skryptu
./local/deploy.sh system/docker-setup.sh
```

**Flow deploy.sh:**
1. Potwierdza deployment
2. Pyta o bazę danych (jeśli wymagana)
3. Pyta o domenę (Cytrus/Cloudflare/lokalnie)
4. Pokazuje "Teraz się zrelaksuj - pracuję..."
5. Wykonuje instalację
6. Konfiguruje domenę (po uruchomieniu usługi!)
7. Pokazuje podsumowanie

### Synchronizacja plików: `sync.sh`

```bash
./local/sync.sh up ./local-folder /remote/path    # Upload
./local/sync.sh down /remote/path ./local-folder  # Download
```

### Konfiguracja domeny Cytrus: `cytrus-domain.sh`

```bash
# Automatyczna domena (np. xyz123.byst.re)
./local/cytrus-domain.sh - 3001 mikrus

# Własna subdomena
./local/cytrus-domain.sh mojapp.byst.re 3001 mikrus
```

Obsługiwane domeny Cytrus:
- `*.byst.re`
- `*.bieda.it`
- `*.toadres.pl`
- `*.tojest.dev`

### Skrypty systemowe: `system/`

```bash
./local/deploy.sh system/docker-setup.sh   # Instalacja Docker
./local/deploy.sh system/caddy-install.sh  # Instalacja Caddy (reverse proxy)
./local/deploy.sh system/power-tools.sh    # CLI tools (yt-dlp, ffmpeg, pup)
```

---

## Backup i restore

### Jak działa backup

Wszystkie aplikacje przechowują dane w `/opt/stacks/<app>/` używając bind mounts.
Skrypt `backup-core.sh` używa rclone do synchronizacji tego katalogu z chmurą.

```
/opt/stacks/                    ☁️ Chmura (Google Drive, Dropbox, etc.)
├── uptime-kuma/data/     ───►  mikrus-backup/stacks/uptime-kuma/data/
├── ntfy/cache/           ───►  mikrus-backup/stacks/ntfy/cache/
├── vaultwarden/data/     ───►  mikrus-backup/stacks/vaultwarden/data/
└── ...
```

### Konfiguracja backupu (jednorazowo)

```bash
# Uruchom wizard - skonfiguruje rclone i cron
./local/setup-backup.sh mikrus

# Wizard:
# 1. Wybierz provider (Google Drive, Dropbox, OneDrive, S3...)
# 2. Zaloguj się przez przeglądarkę (OAuth)
# 3. Opcjonalnie włącz szyfrowanie
# 4. Gotowe - cron uruchomi backup codziennie o 3:00
```

### Ręczne uruchomienie backupu

```bash
# Uruchom backup teraz
ssh mikrus '~/backup-core.sh'

# Sprawdź logi
ssh mikrus 'tail -30 /var/log/mikrus-backup.log'

# Zobacz co jest w chmurze
ssh mikrus 'rclone ls backup_remote:mikrus-backupstacks/'
```

### Restore (przywracanie danych)

```bash
# Przywróć wszystkie dane z chmury
./local/restore.sh mikrus

# Lub ręcznie - przywróć konkretną aplikację
ssh mikrus 'rclone sync backup_remote:mikrus-backupstacks/uptime-kuma /opt/stacks/uptime-kuma'
ssh mikrus 'cd /opt/stacks/uptime-kuma && docker compose up -d'
```

### Weryfikacja backupu

```bash
# Sprawdź czy cron jest ustawiony
ssh mikrus 'crontab -l | grep backup'

# Sprawdź ostatni backup
ssh mikrus 'tail -10 /var/log/mikrus-backup.log'

# Porównaj lokalnie vs chmura
ssh mikrus 'rclone check /opt/stacks backup_remote:mikrus-backupstacks/'
```

---

## Diagnostyka i troubleshooting

### Status kontenerów

```bash
# Lista uruchomionych kontenerów
ssh mikrus 'docker ps'

# Szczegóły z portami
ssh mikrus 'docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"'

# Wszystkie kontenery (także zatrzymane)
ssh mikrus 'docker ps -a'
```

### Logi aplikacji

```bash
# Logi konkretnej aplikacji
ssh mikrus 'cd /opt/stacks/uptime-kuma && docker compose logs --tail 50'

# Logi na żywo (follow)
ssh mikrus 'cd /opt/stacks/uptime-kuma && docker compose logs -f'

# Logi z czasem
ssh mikrus 'cd /opt/stacks/uptime-kuma && docker compose logs --tail 50 -t'
```

### Test lokalny

```bash
# Sprawdź czy aplikacja odpowiada na porcie
ssh mikrus 'curl -s localhost:3001 | head -5'

# Sprawdź nagłówki HTTP
ssh mikrus 'curl -sI localhost:3001'

# Test z zewnątrz (przez domenę)
curl -sI https://mojapp.byst.re
```

### Typowe problemy i rozwiązania

#### 1. Kontener nie startuje

```bash
# Sprawdź logi
ssh mikrus 'cd /opt/stacks/<app> && docker compose logs --tail 100'

# Sprawdź czy obraz się pobrał
ssh mikrus 'docker images | grep <app>'

# Restart kontenera
ssh mikrus 'cd /opt/stacks/<app> && docker compose restart'
```

#### 2. Brak połączenia z bazą danych

```bash
# Sprawdź czy baza jest dostępna
ssh mikrus 'nc -zv <db_host> 5432'

# Test połączenia PostgreSQL
ssh mikrus 'PGPASSWORD=<pass> psql -h <host> -U <user> -d <db> -c "SELECT 1"'
```

#### 3. Domena nie działa (502/504)

- Sprawdź czy kontener działa: `docker ps`
- Sprawdź czy port jest otwarty: `curl localhost:PORT`
- Dla Cytrus: poczekaj 3-5 minut na propagację
- Sprawdź czy port NIE jest bound do 127.0.0.1 (musi być 0.0.0.0 lub bez prefixu)

#### 4. Brak miejsca na dysku

```bash
# Sprawdź miejsce
ssh mikrus 'df -h /'

# Wyczyść nieużywane obrazy Docker
ssh mikrus 'docker system prune -af'

# Wyczyść logi kontenerów
ssh mikrus 'truncate -s 0 /var/lib/docker/containers/*/*-json.log'
```

#### 5. Aplikacja działa lokalnie ale nie przez domenę

Dla Cytrus: port musi być dostępny zewnętrznie (nie 127.0.0.1):
```yaml
# ŹLE - tylko localhost
ports:
  - "127.0.0.1:3000:3000"

# DOBRZE - wszystkie interfejsy
ports:
  - "3000:3000"
```

### Restart aplikacji

```bash
# Restart
ssh mikrus 'cd /opt/stacks/<app> && docker compose restart'

# Pełny restart (down + up)
ssh mikrus 'cd /opt/stacks/<app> && docker compose down && docker compose up -d'

# Restart z pobraniem nowego obrazu
ssh mikrus 'cd /opt/stacks/<app> && docker compose pull && docker compose up -d'
```

### Usunięcie aplikacji

```bash
# Zatrzymaj i usuń kontenery (zachowaj dane)
ssh mikrus 'cd /opt/stacks/<app> && docker compose down'

# Zatrzymaj, usuń kontenery i dane (volumes)
ssh mikrus 'cd /opt/stacks/<app> && docker compose down -v'

# Usuń całkowicie (kontenery + pliki)
ssh mikrus 'cd /opt/stacks/<app> && docker compose down -v && rm -rf /opt/stacks/<app>'
```

---

## Brakujące narzędzia

### Co jest dostępne na Mikrusie

Standardowo zainstalowane:
- `docker`, `docker compose` (po uruchomieniu docker-setup.sh)
- `curl`, `wget`
- `git`
- `nano`, `vim`
- `htop`, `ncdu`

### Instalacja brakujących narzędzi

```bash
# Aktualizacja pakietów (Debian/Ubuntu)
ssh mikrus 'apt update && apt install -y <package>'

# Przykłady:
ssh mikrus 'apt install -y jq'      # JSON processor
ssh mikrus 'apt install -y tree'    # Drzewo katalogów
ssh mikrus 'apt install -y ncdu'    # Disk usage analyzer
```

### Power Tools (opcjonalne)

Skrypt `system/power-tools.sh` instaluje:
- `yt-dlp` - pobieranie wideo
- `ffmpeg` - konwersja mediów
- `pup` - parsowanie HTML

```bash
./local/deploy.sh system/power-tools.sh
```

---

## Architektura

### Struktura katalogów na serwerze

```
/opt/stacks/           # Aplikacje Docker Compose
  ├── uptime-kuma/
  │   ├── docker-compose.yaml
  │   └── data/        # Dane aplikacji (volumes)
  ├── n8n/
  └── ...

/klucz_api             # Klucz API Mikrusa
```

### Dwa sposoby na domenę HTTPS

#### 1. Cytrus (domeny Mikrusa) - ZALECANE

- Automatyczne SSL
- Domeny: `*.byst.re`, `*.bieda.it`, `*.toadres.pl`, `*.tojest.dev`
- Konfiguracja przez API (bez DNS)
- Port musi być dostępny zewnętrznie (nie 127.0.0.1!)

```bash
./local/cytrus-domain.sh mojapp.byst.re 3000 mikrus
```

#### 2. Cloudflare + Caddy (własne domeny)

- Wymaga konfiguracji Cloudflare (`./local/setup-cloudflare.sh`)
- Rekord AAAA do IPv6 serwera
- Caddy jako reverse proxy z auto-SSL

### Bazy danych

#### Współdzielona baza Mikrusa (darmowa)

- Dane z API: `https://api.mikr.us/db.bash`
- PostgreSQL: `psql*.mikr.us`
- MySQL: `mysql*.mikr.us`
- MongoDB: `mongo*.mikr.us`
- **Ograniczenia:** brak uprawnień do rozszerzeń (np. pgcrypto)

#### Dedykowana baza (płatna)

- Panel: https://mikr.us/panel/?a=cloud
- Host: `mws*.mikr.us` (PostgreSQL)
- Pełne uprawnienia, własna baza

---

## Limity i ograniczenia

### Zasoby serwera

- RAM: ~512MB - 2GB (zależnie od pakietu)
- Dysk: ~10-20GB
- **Zawsze ustawiaj limity pamięci w docker-compose.yaml!**

```yaml
deploy:
  resources:
    limits:
      memory: 256M
```

### Rekomendowane limity pamięci

| Aplikacja | Limit RAM |
|-----------|-----------|
| uptime-kuma | 256M |
| ntfy | 128M |
| n8n | 512-768M |
| nocodb | 512M |
| vaultwarden | 128M |

### Porty

- Porty 80 i 443 są zajęte przez Cytrus/Caddy
- Używaj portów > 1024 dla aplikacji
- Unikaj konfliktów - sprawdź `docker ps` przed instalacją

---

## Przykłady sesji

### Instalacja nowej aplikacji

```bash
# 1. Sprawdź czy Docker jest zainstalowany
ssh mikrus 'docker --version' || ./local/deploy.sh system/docker-setup.sh

# 2. Zainstaluj aplikację
./local/deploy.sh uptime-kuma mikrus

# 3. Zweryfikuj
ssh mikrus 'docker ps | grep uptime'
curl -sI https://przydzielona-domena.byst.re
```

### Debug niedziałającej aplikacji

```bash
# 1. Sprawdź status
ssh mikrus 'docker ps -a | grep <app>'

# 2. Sprawdź logi
ssh mikrus 'cd /opt/stacks/<app> && docker compose logs --tail 50'

# 3. Sprawdź lokalnie
ssh mikrus 'curl -s localhost:<port> | head -10'

# 4. Restart jeśli potrzebny
ssh mikrus 'cd /opt/stacks/<app> && docker compose restart'
```

### Aktualizacja aplikacji

```bash
# Pobierz nowy obraz i zrestartuj
ssh mikrus 'cd /opt/stacks/<app> && docker compose pull && docker compose up -d'

# Wyczyść stare obrazy
ssh mikrus 'docker image prune -f'
```

---

## Kontakt i pomoc

- Panel Mikrus: https://mikr.us/panel/
- Dokumentacja API: https://api.mikr.us/
- Tickety support: przez panel Mikrus
