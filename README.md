# 🧰 Mikrus Toolbox

**Zestaw narzędzi "Lazy Engineer" dla Solopreneurów.** 🚀
Zbuduj niezależną, profesjonalną infrastrukturę firmy za ~20 zł miesięcznie, zamiast płacić 2000 zł za subskrypcje SaaS.

> 💡 **Wolisz klikać niż wpisywać komendy?**
> Sprawdź **[Mikrus n8n Manager](https://manager.cytr.us/)** – nasze narzędzie z interfejsem graficznym (GUI), które zainstaluje n8n za Ciebie jednym kliknięciem. Idealne na start!

---

## 🎯 Dla kogo to jest? (Persona: Kamil)
Jesteś przedsiębiorcą, twórcą, freelancerem.
- **Masz dość "podatku od sukcesu":** Im więcej sprzedajesz, tym droższy jest Twój CRM, mailing i Zapier.
- **Chcesz niezależności:** Twoje dane to Twoja własność. Nie chcesz, żeby awaria chmury w USA położyła Twój biznes.
- **Szukasz dźwigni:** Chcesz automatyzować nudną pracę, żeby skupić się na strategii.
- **Jesteś oszczędny, ale nie skąpy:** Wolisz zainwestować raz w konfigurację, niż płacić abonament do końca życia.

Ten toolbox zamienia tani serwer VPS (np. [Mikrus.pl](https://mikrus.pl)) w potężną maszynę klasy Enterprise.

---

## 🛠️ Twój Cyfrowy Arsenał (Co tu jest?)

Przygotowaliśmy gotowe skrypty instalacyjne ("One-Click"), które stawiają usługi zoptymalizowane pod małe zasoby (mało RAM-u, mały dysk).

### 🤖 Automatyzacja & Operacje
| Narzędzie | Zastępuje | Opis |
| :--- | :--- | :--- |
| **n8n** | Make / Zapier | Mózg Twojej firmy. Łączy wszystko ze wszystkim. Wersja zoptymalizowana pod zewnętrzną bazę danych (oszczędza RAM). |
| **Dockge** | Portainer | Panel sterowania. Zarządzaj wszystkimi usługami przez przeglądarkę, widząc pliki konfiguracyjne. |
| **Uptime Kuma** | UptimeRobot | Twój stróż nocny. Sprawdza czy Twoje strony działają i wysyła alarm, gdy coś padnie. |
| **ntfy** | Pushover | Serwer powiadomień PUSH. Wysyłaj alerty z n8n prosto na telefon. |
| **Redis** | - | Pamięć podręczna (cache). Przyspiesza n8n i inne aplikacje. |
| **MCP Docker** | - | Most AI ↔ Serwer. Pozwól Claude/Cursor zarządzać kontenerami przez SSH. |
| **MinIO** | AWS S3 | Self-hosted storage S3-compatible. Dla Cap, Typebot, lub własnych plików. |
| **Power Tools** | - | Zestaw CLI (`yt-dlp`, `ffmpeg`, `pup`) do zaawansowanej automatyzacji na serwerze. |

### 💰 Marketing & Sprzedaż
| Narzędzie | Zastępuje | Opis |
| :--- | :--- | :--- |
| **GateFlow** | EasyCart / Gumroad | **Twój własny sklep z produktami cyfrowymi.** E-booki, kursy, szablony. 0 zł/mies, 0% prowizji. Lejki, OTO, kupony, Omnibus EU. |
| **Listmonk** | Mailchimp / ActiveCampaign | System newsletterowy. Wysyłaj miliony maili za grosze (przez Amazon SES lub inny SMTP). |
| **Typebot** | Typeform | Interaktywne formularze i chatboty. Zbieraj leady, rób ankiety, sprzedawaj w rozmowie. |
| **Cap** | Loom | Nagrywaj ekran i udostępniaj wideo. Idealny do tutoriali i komunikacji asynchronicznej. |
| **Umami** | Google Analytics | Statystyki WWW. Proste, czytelne, szanujące prywatność (bez RODO-paniki). |
| **Cookie Hub** | Cookiebot / CookieYes | Centralny serwer zgód RODO (Klaro!). Zarządzaj ciasteczkami na wszystkich stronach z jednego miejsca. |
| **FileBrowser** | Tiiny.host / Dropbox | Prywatny Google Drive + Hosting (Tiiny.host Killer). Wrzucaj PDF-y i Landing Page przez WWW. |

### 🏢 Biuro & Produktywność
| Narzędzie | Zastępuje | Opis |
| :--- | :--- | :--- |
| **NocoDB** | Airtable | Twoja baza danych jako Arkusz Kalkulacyjny. Trzymaj tu dane klientów, zamówienia, projekty. |
| **Stirling-PDF** | Adobe Acrobat Pro | Edytuj, łącz, dziel i podpisuj PDF-y w przeglądarce. Bez wysyłania plików w świat. ⚠️ **Wymaga 2GB RAM (Mikrus 2.0+)** |
| **Gotenberg** | - | API do konwersji dokumentów (HTML→PDF, DOCX→PDF). Lekka alternatywa dla Stirling-PDF (~150MB RAM). |
| **Vaultwarden** | 1Password / LastPass | Bezpieczny sejf na hasła dla całej firmy. |
| **LinkStack** | Linktree | Twoja wizytówka "Link in Bio" z panelem admina. |
| **LittleLink** | Linktree | Wizytówka "Link in Bio" – wersja ultra-lekka (czysty HTML). |

---

## 🔗 Ekosystem: Jak to połączyć w maszynę?

Te narzędzia nie są samotnymi wyspami. Razem tworzą **System Operacyjny Firmy**.

### Scenariusz: "Automatyczna Sprzedaż E-booka"
1.  **Typebot:** Klient wchodzi na stronę i rozmawia z botem, który bada jego potrzeby.
2.  **GateFlow:** Bot kieruje klienta do płatności (Stripe) za e-booka.
3.  **n8n:** Wykrywa nową płatność (Webhook ze Stripe).
    *   Dodaje klienta do **NocoDB** (CRM).
    *   Wysyła e-booka mailem.
    *   Wystawia fakturę (przez API Fakturowni).
    *   Dodaje klienta do **Listmonk** (Newsletter).
4.  **Umami:** Śledzi konwersję na każdym etapie.

Wszystko dzieje się automatycznie, na Twoim serwerze, bez miesięcznych opłat.

---

## 🚀 Instrukcja Startu (Krok po kroku)

### Wymagania
1.  **Serwer VPS:** Np. Mikrus 3.0 lub 4.0.
2.  **Konto GitHub:** Do pobierania skryptów.
3.  **Domena:** Np. `mojafirma.pl` podpięta pod Cloudflare (zalecane) lub bezpośrednio na IP serwera.

### Krok 0: Przygotowanie (Na Twoim komputerze)
Musisz mieć skonfigurowany dostęp SSH do serwera (alias `mikrus`).

**Skopiuj i wklej w terminalu:**
```bash
bash <(curl -s https://raw.githubusercontent.com/pavvel11/mikrus-n8n-manager/main/setup_mikrus.sh)
```
Skrypt zapyta o dane z maila od Mikrusa (host, port, hasło) i skonfiguruje połączenie SSH.

Upewnij się też, że masz zainstalowanego **Gita** i **Rclone** (do backupów).

### Krok 1: Pobierz Toolbox (Na Twoim komputerze)
```bash
git clone https://github.com/pavvel11/mikrus-toolbox.git
cd mikrus-toolbox
```

### 🤖 Opcja "AI Assistant" - niech Claude zrobi to za Ciebie

Nie chcesz czytać dokumentacji? Masz zainstalowane [Claude Code](https://claude.ai/code)?

```bash
cd mikrus-toolbox
claude
```

I po prostu powiedz co chcesz:
- *"Zainstaluj mi n8n na serwerze hanna"*
- *"Skonfiguruj backup do Google Drive"*
- *"Sprawdź czy wszystkie kontenery działają"*
- *"Wystaw Dockge pod domeną panel.mojafirma.pl"*

Claude zna ten toolbox (dzięki plikowi `CLAUDE.md`) i przeprowadzi Cię przez cały proces krok po kroku. Zadba o DNS, porty, certyfikaty SSL - wszystko.

> 💡 **To jest magia:** AI + dobre skrypty = zero stresu przy administracji serwerem.

### Krok 2: Instalacja Fundamentów (Na Serwerze)
Użyjemy naszego magicznego skryptu `local/deploy.sh`, który wysyła instrukcje na serwer.

1.  **Docker & Optymalizacja:**
    ```bash
    ./local/deploy.sh system/docker-setup.sh
    ```
    > 💡 **Czym to się różni od standardowego skryptu Mikrusa?**
    > Nasz skrypt używa oficjalnego NOOBS od Mikrusa, ale **dodaje rotację logów** (max 30MB na kontener). Bez tego logi Dockera mogą zapchać Ci dysk w kilka tygodni. Dodaje też `live-restore` - kontenery przeżyją restart Dockera.
2.  **Caddy Server:** (Reverse proxy z automatycznym HTTPS)
    ```bash
    ./local/deploy.sh system/caddy-install.sh
    ```

    > 💡 **Co to robi?**
    > Caddy to serwer WWW który automatycznie załatwia certyfikaty SSL (Let's Encrypt).
    > Po instalacji dostajesz komendę `mikrus-expose` do łatwego wystawiania aplikacji:
    > ```bash
    > # Na serwerze (ssh mikrus):
    > mikrus-expose n8n.mojadomena.pl 5678
    > ```
    > To wszystko! Caddy automatycznie:
    > - Pobiera certyfikat SSL dla domeny
    > - Przekierowuje ruch z `https://n8n.mojadomena.pl` na `localhost:5678`
    > - Odnawia certyfikaty automatycznie
    >
    > 💡 **Dwie drogi do HTTPS na Mikrusie:**
    >
    > **Opcja A: Cytrus (łatwiejsza, bez instalacji)**
    > Mikrus ma wbudowany serwer WWW "Cytrus" który załatwia SSL za Ciebie:
    > 1. Rekord DNS: `A` → `135.181.95.85` (IP Cytrusa)
    > 2. W [Panelu Mikrus](https://mikr.us/panel/?a=hosting_domeny) dodaj domenę i przekieruj na port, np. `srv34.mikr.us:5678`
    > 3. Gotowe! SSL automatyczny.
    > 📖 [Wiki Mikrus - Cytrus](https://wiki.mikr.us/cytrus/)
    >
    > **Opcja B: Caddy (więcej kontroli, nasz skrypt)**
    > Jeśli chcesz własny reverse proxy:
    > 1. Rekord DNS: `A` → IP serwera (lub `AAAA` → IPv6 przez Cloudflare)
    > 2. Na serwerze: `mikrus-expose n8n.domena.pl 5678`
    > 3. Caddy pobiera SSL z Let's Encrypt
    > 📖 [Wiki Mikrus - Cloudflare](https://wiki.mikr.us/podpiecie_domeny_przez_cloudflare/) | [Dokumentacja Caddy](https://caddyserver.com/docs/)
    >
    > **Kiedy Cytrus, kiedy Caddy?**
    > | | Cytrus | Caddy |
    > |---|---|---|
    > | Konfiguracja | Panel Mikrusa (klik) | Terminal (`mikrus-expose`) |
    > | Wymagana wiedza | Minimalna | Podstawowa |
    > | Niezależność | Współdzielony serwer Mikrusa | Twój własny proces |
    >
    > *Tip: Na start Cytrus wystarczy. Caddy daje więcej kontroli i jest w pełni na Twoim serwerze.*

3.  **Cloudflare DNS:** (Automatyzacja domen - ZALECANE)
    ```bash
    ./local/setup-cloudflare.sh
    ```

    > 💡 **Po co to?**
    >
    > **Problem:** Mikrus używa IPv6, a większość polskich ISP obsługuje tylko IPv4. Bez Cloudflare Twoje strony nie będą działać dla wielu użytkowników!
    >
    > **Rozwiązanie:** Cloudflare działa jako "tłumacz" - przyjmuje ruch IPv4 i przekazuje go na IPv6 Mikrusa. Plus: automatyzacja DNS!
    >
    > **Co daje konfiguracja?**
    > - Dodawanie rekordów DNS jednym poleceniem (zamiast klikania w panelu)
    > - Strony działają dla WSZYSTKICH (nie tylko użytkowników IPv6)
    > - Darmowy SSL, CDN i ochrona DDoS
    >
    > **Wymagania:**
    > 1. Domena (np. z [OVH](https://www.ovhcloud.com/pl/domains/) - od ~12 zł/rok)
    > 2. Darmowe konto [Cloudflare](https://www.cloudflare.com/)
    > 3. Domena przekierowana na serwery DNS Cloudflare
    >
    > 📖 **[Pełna instrukcja: Jak skonfigurować domenę z Cloudflare](docs/cloudflare-domain-setup.md)**
    >
    > **Po konfiguracji - dodawanie domen to bajka:**
    > ```bash
    > # DNS (automatycznie pobiera IPv6 z serwera!)
    > ./local/dns-add.sh status.mojafirma.pl
    >
    > # HTTPS
    > ssh mikrus 'mikrus-expose status.mojafirma.pl 3001'
    > ```

### Krok 4: Backup - ZRÓB TO OD RAZU!

Nie pozwól, żeby awaria zniszczyła Twój biznes. Skonfiguruj backup **zanim** zaczniesz instalować aplikacje.

#### Opcja A: Backup Mikrusa (darmowy, 200MB)

Najprostszy start - wbudowany serwer backupowy Mikrusa (`strych.mikr.us`).

**Co jest backupowane:**
- `/etc/` - konfiguracje systemowe
- `/home/` - pliki użytkowników
- `/var/log/` - logi

**Kiedy to wystarczy:**
- Masz tylko konfiguracje aplikacji (docker-compose, nginx, cron)
- Dane trzymasz w zewnętrznej bazie (PostgreSQL Mikrusa/Cloud)
- Pliki użytkowników są małe

**Kiedy potrzebujesz więcej (Opcja B):**
- Masz duże pliki w `/opt/stacks/` (uploady, media)
- Baza danych jest lokalna (SQLite, pliki)
- Chcesz szyfrowany backup poza infrastrukturą Mikrusa

**Instalacja:**
1. Aktywuj backup w [Panelu Mikrus → Backup](https://mikr.us/panel/?a=backup)
2. Uruchom konfigurację:
   ```bash
   ./local/deploy.sh system/setup-backup-mikrus.sh
   ```
3. Gotowe! Codziennie backup leci na `strych.mikr.us`.

**Restore:**
```bash
# 1. Zaloguj się na serwer
ssh mikrus

# 2. Zobacz co masz na strychu
ssh -i /backup_key $(whoami)@strych.mikr.us "ls ~/backup/"

# 3. Skopiuj potrzebne pliki
scp -i /backup_key $(whoami)@strych.mikr.us:~/backup/etc/plik.conf /etc/
rsync -av -e 'ssh -i /backup_key' $(whoami)@strych.mikr.us:~/backup/opt/ /opt/
```

> ⚠️ Limit 200MB. Dla większych danych lub szyfrowanego backupu użyj Opcji B.

#### Opcja B: Backup do chmury (Google Drive / Dropbox)

Szyfrowany backup do własnej chmury - bez limitu, pełna kontrola.

**Co jest backupowane:**
- `/opt/stacks/` - wszystkie aplikacje Docker (n8n, Listmonk, dane)
- `/opt/dockge/` - panel zarządzania kontenerami

**Kiedy wybrać tę opcję:**
- Masz dużo danych (uploady, media, lokalne bazy)
- Chcesz szyfrowany backup (hasło znasz tylko Ty)
- Potrzebujesz backup poza infrastrukturą Mikrusa (disaster recovery)
- Masz już Google Drive / Dropbox z wolnym miejscem

**Wspierani providerzy:**
- Google Drive (zalecany - 15GB free)
- Dropbox
- OneDrive
- Amazon S3 / Wasabi / MinIO
- Mega

**Wymagania lokalne:**
- Git Bash / Terminal z SSH
- Rclone (do autoryzacji OAuth przez przeglądarkę):
  - Mac: `brew install rclone`
  - Linux: `curl https://rclone.org/install.sh | sudo bash`
  - Windows: `winget install rclone` lub [pobierz](https://rclone.org/downloads/)

**Instalacja:**
1. Uruchom kreator na swoim komputerze:
   ```bash
   ./local/setup-backup.sh           # domyślnie 'mikrus'
   ./local/setup-backup.sh hanna     # lub inny serwer
   ```
2. Wybierz provider (Google Drive, Dropbox, OneDrive, S3...)
3. Zaloguj się w przeglądarce
4. Włącz szyfrowanie (zalecane) - **zapamiętaj hasło!**
5. Gotowe! Serwer co noc o 3:00 wysyła dane do chmury.

**Restore:**
```bash
# Pełne przywracanie (zatrzymuje Docker, nadpisuje dane)
./local/restore.sh           # domyślnie 'mikrus'
./local/restore.sh hanna     # lub inny serwer
```

**Ręczny backup / sprawdzenie:**
```bash
ssh mikrus '~/backup-core.sh'              # uruchom backup teraz
ssh mikrus 'tail -50 /var/log/mikrus-backup.log'  # sprawdź logi
```

**Zmiana backupowanych katalogów:**
```bash
ssh mikrus 'nano ~/backup-core.sh'
```
Znajdź sekcję `SOURCE_DIRS` i dodaj/usuń katalogi:
```bash
SOURCE_DIRS=(
    "/opt/dockge"
    "/opt/stacks"
    "/home"           # <- dodaj np. katalog home
    "/etc/caddy"      # <- lub konfigurację Caddy
)
```

> 💡 Backup jest szyfrowany na serwerze przed wysłaniem. Nawet Google nie widzi Twoich danych.

### Krok 5: Instalacja Aplikacji

**Panel Sterowania (Dockge)** - zacznij od tego:
```bash
./local/deploy.sh dockge
```
Dockge pozwala zarządzać kontenerami przez przeglądarkę. Nie wymaga bazy danych.

**Inne aplikacje:**
Każda aplikacja ma swój folder w `apps/` z pełną dokumentacją:

| Aplikacja | Wymaga PostgreSQL | Dokumentacja |
|---|---|---|
| **n8n** | Tak | [apps/n8n/README.md](apps/n8n/README.md) |
| **Listmonk** | Tak | [apps/listmonk/README.md](apps/listmonk/README.md) |
| **Uptime Kuma** | Nie | [apps/uptime-kuma/README.md](apps/uptime-kuma/README.md) |
| **Umami** | Tak | [apps/umami/README.md](apps/umami/README.md) |

> 💡 **PostgreSQL na Mikrusie:** Darmowa współdzielona baza (200MB) w [Panelu](https://mikr.us/panel/?a=postgres) lub dedykowana 10GB za 29 zł/rok w [Cloud](https://mikr.us/panel/?a=cloud).

---

## ⚡ Power User Zone (Dla Zaawansowanych)

### 🛠️ Power Tools (`system/power-tools.sh`)
Zainstaluj zestaw potężnych narzędzi CLI na serwerze: `yt-dlp` (pobieranie wideo), `ffmpeg` (konwersja), `pup` (HTML parsing).

```bash
./local/deploy.sh system/power-tools.sh
```

**Jak użyć tego w n8n?**
n8n działa w kontenerze, a te narzędzia są na serwerze (hoście).
1.  W n8n użyj węzła **"Execute Command"**.
2.  Jako komendę wpisz: `ssh user@172.17.0.1 "yt-dlp https://youtube.com/..."` (połącz się z kontenera do hosta).
3.  *Tip:* Możesz zapytać AI (Claude/Gemini) o inne przydatne paczki apt i zainstalować je ręcznie przez SSH.

### 📦 Pełny Backup n8n
Zwykły backup plików to za mało. Ten skrypt eksportuje Twoje workflowy do JSON i szyfruje credentiale.
```bash
./local/deploy.sh apps/n8n/backup.sh
```
Uruchamiaj go przed każdą dużą zmianą lub dodaj do Crona.

---

## 💡 Przydatne Komendy

### 🔍 Sprawdzanie czy usługa działa

Zainstalowałeś coś i nie wiesz czy działa? Oto zestaw komend diagnostycznych:

```bash
# 1. Czy kontener w ogóle istnieje i działa?
ssh mikrus 'docker ps | grep nazwa-uslugi'

# 2. Logi kontenera (ostatnie 50 linii)
ssh mikrus 'cd /opt/stacks/nazwa-uslugi && docker compose logs --tail 50'

# 3. Czy port odpowiada? (200 lub 302 = OK)
ssh mikrus 'curl -s -o /dev/null -w "%{http_code}" http://localhost:PORT'

# 4. Ile zasobów zużywa?
ssh mikrus 'docker stats --no-stream'
```

**Przykład dla Dockge:**
```bash
ssh mikrus 'docker ps | grep dockge'
ssh mikrus 'curl -s -o /dev/null -w "%{http_code}" http://localhost:5001'
```

### 🚇 Tunel SSH - dostęp bez domeny

**Co to jest?**
Tunel SSH to "magiczny portal" który łączy port na Twoim komputerze z portem na serwerze. Dzięki temu możesz otworzyć aplikację w przeglądarce **bez konfigurowania domeny i DNS**.

**Kiedy to przydatne?**
- Testujesz aplikację przed wystawieniem publicznym
- Nie masz jeszcze domeny
- Chcesz szybko zerknąć czy coś działa
- Dostęp do paneli administracyjnych które nie powinny być publiczne

**Jak uruchomić tunel?**
```bash
# Składnia: ssh -L lokalny_port:localhost:zdalny_port alias_serwera
ssh -L 5001:localhost:5001 mikrus
```

Teraz otwórz w przeglądarce: `http://localhost:5001` - zobaczysz Dockge!

**Popularne porty:**
| Usługa | Port | Komenda tunelu |
|--------|------|----------------|
| Dockge | 5001 | `ssh -L 5001:localhost:5001 mikrus` |
| n8n | 5678 | `ssh -L 5678:localhost:5678 mikrus` |
| Uptime Kuma | 3001 | `ssh -L 3001:localhost:3001 mikrus` |
| ntfy | 8085 | `ssh -L 8085:localhost:8085 mikrus` |

**Jak wyjść z tunelu?**
- Wpisz `exit` w terminalu, lub
- Naciśnij `Ctrl+D`, lub
- Po prostu zamknij okno terminala

> 💡 **Pro tip:** Możesz otworzyć wiele tuneli naraz:
> ```bash
> ssh -L 5001:localhost:5001 -L 5678:localhost:5678 mikrus
> ```

> ⚠️ **Uwaga:** Tunel działa tylko gdy terminal jest otwarty. Zamknięcie terminala = koniec tunelu.

### Synchronizacja Plików (Lokalny komputer <-> Mikrus)
Chcesz wrzucić pliki strony na serwer? Albo pobrać logi?
```bash
# Wyślij na serwer (UP)
./local/sync.sh up ./moja-strona /var/www/moja-strona

# Pobierz z serwera (DOWN)
./local/sync.sh down /opt/stacks/n8n/docker-compose.yaml ./n8n-backup/
```

### Ratunek (Emergency Restore)
Coś wybuchło? Przywróć serwer do stanu z wczoraj.
```bash
./local/restore.sh
```

### Dodawanie domen (HTTPS)

#### Opcja A: Automatycznie (Cloudflare)
Jeśli masz domeny w Cloudflare, możesz dodawać rekordy DNS jedną komendą:

```bash
# Jednorazowa konfiguracja
./local/setup-cloudflare.sh

# Potem dla każdej aplikacji (IP pobiera się automatycznie z serwera!):
./local/dns-add.sh status.mojafirma.pl           # używa 'mikrus'
./local/dns-add.sh status.mojafirma.pl hanna     # używa 'hanna'
ssh mikrus 'mikrus-expose status.mojafirma.pl 3001'
```

#### Opcja B: Ręcznie (dowolny provider)
1. Dodaj rekord A w panelu DNS swojego providera (OVH, home.pl, Cloudflare...)
2. Zaloguj się na serwer (`ssh mikrus`) i wpisz:
```bash
mikrus-expose mojadomena.pl 5000
```
Caddy zrobi resztę (Certyfikat, Config, Reload).

---

## ❓ FAQ

**Q: Czy to jest bezpieczne?**
A: Tak.
- Wszystkie usługi są za firewallem lub w kontenerach.
- Dostęp z zewnątrz tylko przez HTTPS (Caddy).
- Masz szyfrowane backupy off-site (poza serwerem).

**Q: Ile RAMu potrzebuję?**
A:
- Podstawa (Caddy + Dockge): ~100MB
- n8n (z zewnętrzną bazą): ~300-400MB
- Typebot: ~300MB
- Listmonk: ~50MB
- Uptime Kuma: ~250MB
- Vaultwarden: ~50MB
- Gotenberg: ~150MB (API do konwersji dokumentów - lekka alternatywa dla Stirling-PDF)
- ⚠️ **Stirling-PDF: ~500MB+** (Java/Spring Boot - wymaga minimum Mikrus 2.0!)

*Rekomendacja:* Mikrus 3.0 (1GB RAM) uciągnie n8n + 2-3 mniejsze usługi. Do pełnego zestawu (n8n + Typebot + GateFlow) zalecany Mikrus 4.0 (2GB RAM). **Stirling-PDF instaluj tylko na Mikrus 2.0+ (2GB RAM).** Na Mikrus 1.0 użyj **Gotenberg** zamiast Stirling-PDF.

**Q: Co z bazą danych?**
A: Większość skryptów (n8n, Umami, Listmonk) poprosi o dane do Postgresa. **NIE INSTALUJ POSTGRESA NA MIKRUSIE 3.0.** Kup "Cegłę" bazy danych na Mikrusie (29 zł/rok) lub użyj darmowego tieru w chmurze (Neon, Supabase). To oszczędza mnóstwo zasobów.

---

## 💰 Kalkulator Oszczędności (DRAFT)

> ⚠️ **Sekcja w budowie** - uzupełnimy po testach wszystkich narzędzi

### Koszt Mikrusa

| Plan | RAM | Dysk | Cena/mies | Cena/rok |
|------|-----|------|-----------|----------|
| Mikrus 1.0 | 256MB | 2.5GB | 7 zł | 84 zł |
| Mikrus 2.0 | 512MB | 5GB | 12 zł | 144 zł |
| Mikrus 3.0 | 1GB | 10GB | 20 zł | 240 zł |
| Mikrus 4.0 | 2GB | 20GB | 35 zł | 420 zł |
| PostgreSQL (dedykowana) | - | 10GB | ~2.5 zł | 29 zł |
| Domena (.pl) | - | - | - | ~50 zł |

### Ile kosztują SaaS-y w chmurze?

| Narzędzie | Zastępuje | Cena SaaS/mies | Cena SaaS/rok | Na Mikrusie |
|-----------|-----------|----------------|---------------|-------------|
| n8n | Zapier Pro | $29-99 | $348-1188 | 0 zł |
| Listmonk | Mailchimp (5k) | $50+ | $600+ | 0 zł |
| Typebot | Typeform Pro | $50+ | $600+ | 0 zł |
| Umami | - | $9+ | $108+ | 0 zł |
| Uptime Kuma | UptimeRobot Pro | $7+ | $84+ | 0 zł |
| NocoDB | Airtable Pro | $20+ | $240+ | 0 zł |
| Cap | Loom Business | $15+ | $180+ | 0 zł |
| GateFlow | Gumroad/EasyCart | 10%+ prowizji | $$$$ | 0 zł |
| FileBrowser | Tiiny.host Pro | $6+ | $72+ | 0 zł |
| Vaultwarden | 1Password Teams | $8/user | $96/user | 0 zł |
| Stirling-PDF | Adobe Acrobat | $15+ | $180+ | 0 zł |

> 📊 TODO: Dokładny research cen (tier, limity, ukryte koszty)

### Case Study: Solopreneur (sprzedaż kursów)

**Potrzeby:**
- Automatyzacja sprzedaży (n8n)
- Newsletter (Listmonk)
- Formularz lead capture (Typebot)
- Monitoring (Uptime Kuma)
- Analityka (Umami)
- Hosting PDF-ów (FileBrowser)

**Koszt SaaS:**
| Usługa | Miesięcznie | Rocznie |
|--------|-------------|---------|
| Zapier Pro | $29 | $348 |
| Mailchimp (5k) | $50 | $600 |
| Typeform Pro | $50 | $600 |
| UptimeRobot Pro | $7 | $84 |
| GA4 (darmowy, ale dane Google) | $0 | $0 |
| Tiiny.host Pro | $6 | $72 |
| **SUMA** | **$142** | **$1704 (~7000 zł)** |

**Koszt Mikrus:**
| Pozycja | Rocznie |
|---------|---------|
| Mikrus 3.0 | 240 zł |
| Domena .pl | 50 zł |
| PostgreSQL (Cloud) | 29 zł |
| **SUMA** | **319 zł** |

**Oszczędność:** ~6700 zł/rok (95%!)

### Case Study: Mała Agencja (5 osób)

> TODO: Scenariusz z Vaultwarden, NocoDB jako CRM, większe limity mailingowe

### Case Study: SaaS Founder (MVP)

> TODO: Scenariusz z Cap do onboardingu, Typebot jako support chat, n8n do integracji

### Czas instalacji

| Co | Pierwszy raz | Powtórka |
|----|--------------|----------|
| Setup serwera + Docker | 30 min | 10 min |
| n8n + baza danych | 15 min | 5 min |
| Każda kolejna aplikacja | 5-10 min | 2-5 min |
| Pełny stack (10 narzędzi) | 2-3h | 1h |

> 💡 Z Claude Code czas spada o ~50% (AI robi za Ciebie)

### Wymagania serwera

| Stack | Wymagany plan | RAM używany |
|-------|---------------|-------------|
| Podstawa (Caddy + Dockge) | Mikrus 1.0 | ~100MB |
| + n8n | Mikrus 3.0 | ~500MB |
| + Listmonk + Uptime Kuma | Mikrus 3.0 | ~800MB |
| + Typebot + GateFlow | Mikrus 4.0 | ~1.5GB |
| Pełny stack | Mikrus 4.0 | ~1.8GB |

> ⚠️ Stirling-PDF wymaga Mikrus 4.0 (2GB RAM). Alternatywa: Gotenberg (~150MB)

---
**Twórca:** Paweł (Lazy Engineer)
*Automatyzuj mądrze.*