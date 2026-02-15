# Mikrus Toolbox

**25 self-hosted aplikacji. Jeden serwer. Zero abonamentów.**

Zamień tani polski VPS ([Mikrus.pl](https://mikrus.pl)) w pełną infrastrukturę firmy - automatyzacja, mailing, analityka, CRM, sklep z produktami cyfrowymi - za ~20 zł/mies zamiast ~7000 zł/rok w SaaS-ach.

```bash
git clone https://github.com/pavvel11/mikrus-toolbox.git
cd mikrus-toolbox
./local/deploy.sh n8n        # → n8n działa na Twoim serwerze
```

Każda aplikacja to jeden `deploy.sh` - skrypt pyta o domenę, bazę danych, sprawdza zasoby serwera i instaluje zoptymalizowaną wersję pod małe VPS-y.

---

## Spis treści

- [Dla kogo?](#dla-kogo)
- [25 aplikacji](#25-aplikacji-w-arsenale)
- [Jak to działa razem](#jak-to-działa-razem)
- [Szybki start](#szybki-start)
- [Kalkulator oszczędności](#kalkulator-oszczędności)
- [Coolify - bonus dla dużych serwerów](#coolify---prywatny-herokuvercel-mikrus-41)
- [FAQ](#faq)

---

## Dla kogo?

Dla **solopreneurów, freelancerów i małych firm**, które:

- Płacą za Zapier, Mailchimp, Airtable, Typeform i widzą, jak rachunki rosną z każdym kontaktem
- Chcą mieć dane na **własnym serwerze** - nie u Google'a, nie w USA
- Wolą zainwestować raz w konfigurację, niż płacić abonament do końca życia
- Szukają **dźwigni** - automatyzacji, która pracuje 24/7 bez opłat za "execution"

> Nie chcesz wpisywać komend? Sprawdź **[Mikrus n8n Manager](https://manager.cytr.us/)** - GUI, które zainstaluje n8n jednym kliknięciem.

---

## 25 aplikacji w arsenale

### Automatyzacja i operacje

| Aplikacja | Zastępuje | Co robi |
| :--- | :--- | :--- |
| [**n8n**](apps/n8n/) | Zapier / Make | Mózg firmy. Łączy wszystko ze wszystkim - CRM, maile, płatności, API. |
| [**Dockge**](apps/dockge/) | Portainer | Panel do zarządzania kontenerami Docker przez przeglądarkę. |
| [**Uptime Kuma**](apps/uptime-kuma/) | UptimeRobot | Monitoring stron i usług z alertami na telefon. |
| [**ntfy**](apps/ntfy/) | Pushover | Serwer powiadomień push. Wysyłaj alerty z n8n na telefon. |
| [**Redis**](apps/redis/) | - | Cache. Przyspiesza n8n, WordPress i inne aplikacje. |
| [**Crawl4AI**](apps/crawl4ai/) | ScrapingBee | AI web scraper z REST API. Markdown, LLM extraction, JS rendering. |
| [**MCP Docker**](apps/mcp-docker/) | - | Most AI-serwer. Pozwól Claude/Cursor zarządzać kontenerami. |
| [**MinIO**](apps/minio/) | AWS S3 | Self-hosted object storage (S3-compatible). |

### Marketing i sprzedaż

| Aplikacja | Zastępuje | Co robi |
| :--- | :--- | :--- |
| [**GateFlow**](apps/gateflow/) | Gumroad / EasyCart | Sklep z produktami cyfrowymi. 0 zł/mies, 0% prowizji. Lejki, kupony, Omnibus EU. |
| [**Listmonk**](apps/listmonk/) | Mailchimp | Newsletter na miliony maili za grosze (przez Amazon SES lub SMTP). |
| [**Typebot**](apps/typebot/) | Typeform | Chatboty i formularze. Zbieraj leady, rób ankiety, sprzedawaj w rozmowie. |
| [**Postiz**](apps/postiz/) | Buffer / Hootsuite | Planuj posty na X, LinkedIn, Instagram, Facebook, TikTok. |
| [**Cap**](apps/cap/) | Loom | Nagrywaj ekran i udostępniaj wideo. Tutoriale, async communication. |
| [**Umami**](apps/umami/) | Google Analytics | Analityka bez cookies, bez RODO-paniki, z szacunkiem do prywatności. |
| [**Cookie Hub**](apps/cookie-hub/) | Cookiebot | Centralny serwer zgód RODO dla wszystkich Twoich stron. |
| [**FileBrowser**](apps/filebrowser/) | Dropbox / Tiiny.host | Prywatny dysk z UI + hosting plików i landing page'y. |

### Biuro i produktywność

| Aplikacja | Zastępuje | Co robi |
| :--- | :--- | :--- |
| [**WordPress**](apps/wordpress/) | WordPress.com | Performance Edition: Nginx + PHP-FPM + Redis Object Cache, auto-tuning. |
| [**NocoDB**](apps/nocodb/) | Airtable | Baza danych z interfejsem arkusza kalkulacyjnego. CRM, projekty, zamówienia. |
| [**Stirling-PDF**](apps/stirling-pdf/) | Adobe Acrobat | Edycja, łączenie, podpisywanie PDF-ów w przeglądarce. |
| [**Gotenberg**](apps/gotenberg/) | - | API do konwersji dokumentów (HTML/DOCX/ODT → PDF). Lekki: ~150MB RAM. |
| [**ConvertX**](apps/convertx/) | CloudConvert | Konwerter 800+ formatów plików w przeglądarce. |
| [**Vaultwarden**](apps/vaultwarden/) | 1Password | Menedżer haseł dla całej firmy. Kompatybilny z Bitwarden. |
| [**LinkStack**](apps/linkstack/) | Linktree | Wizytówka "Link in Bio" z panelem admina. |
| [**LittleLink**](apps/littlelink/) | Linktree | Wizytówka "Link in Bio" - wersja ultra-lekka, czysty HTML. |

> Każda aplikacja ma swój `README.md` z dokumentacją, wymaganiami i opcjami konfiguracji.

---

## Jak to działa razem

Te aplikacje to nie oddzielne wyspy. Razem tworzą **system operacyjny firmy**.

**Przykład: automatyczna sprzedaż e-booka**

```
Klient → Typebot (chatbot) → GateFlow (płatność Stripe)
                                    ↓
                              n8n (webhook)
                             /    |    \     \
                        NocoDB  Email  Faktura  Listmonk
                        (CRM)  (ebook)  (API)  (newsletter)
                                    ↓
                              Umami (konwersja)
```

1. **Typebot** - klient rozmawia z botem, który bada potrzeby
2. **GateFlow** - bot kieruje do płatności za e-booka
3. **n8n** - wykrywa płatność i automatycznie: dodaje klienta do CRM (**NocoDB**), wysyła e-booka mailem, wystawia fakturę, zapisuje do newslettera (**Listmonk**)
4. **Umami** - śledzi konwersję

Wszystko na Twoim serwerze. Zero opłat za "execution". Zero limitów.

---

## Szybki start

### Wymagania

- **Serwer VPS** - [Mikrus](https://mikrus.pl) 3.0+ (1GB RAM, 10GB dysk, od 20 zł/mies)
- **Domena** - np. z [OVH](https://www.ovhcloud.com/pl/domains/) (od ~12 zł/rok)
- **Terminal** z dostępem SSH

### 1. Konfiguracja SSH

```bash
# Linux / macOS
bash <(curl -s https://raw.githubusercontent.com/pavvel11/mikrus-toolbox/main/local/setup-ssh.sh)

# Windows (PowerShell)
iwr -useb https://raw.githubusercontent.com/pavvel11/mikrus-toolbox/main/local/setup-ssh.ps1 | iex
```

Skrypt zapyta o dane z maila od Mikrusa (host, port, hasło) i skonfiguruje klucz SSH + alias.

### 2. Pobierz toolbox

```bash
git clone https://github.com/pavvel11/mikrus-toolbox.git
cd mikrus-toolbox
```

### 3. Zainstaluj fundamenty

```bash
./local/deploy.sh system/docker-setup.sh    # Docker + optymalizacja logów
./local/deploy.sh system/caddy-install.sh   # Reverse proxy z auto-SSL
```

### 4. Zainstaluj aplikacje

```bash
./local/deploy.sh dockge                    # Panel Docker (start od tego)
./local/deploy.sh n8n                       # Automatyzacja
./local/deploy.sh uptime-kuma               # Monitoring
```

`deploy.sh` zadba o wszystko - sprawdzi zasoby serwera, zapyta o domenę i bazę danych, zainstaluje aplikację i zweryfikuje czy działa.

### 5. Backup - zrób to od razu

```bash
./local/setup-backup.sh     # Szyfrowany backup do Google Drive / Dropbox
```

> Szczegóły: [docs/backup.md](docs/backup.md)

### Domeny i HTTPS

Dwie opcje:

| | Cytrus (łatwiej) | Caddy (więcej kontroli) |
|---|---|---|
| Konfiguracja | Panel Mikrusa | Terminal |
| SSL | Automatyczny | Let's Encrypt |
| Jak | [Panel → Domeny](https://mikr.us/panel/?a=hosting_domeny) | `ssh mikrus 'mikrus-expose domena.pl 5678'` |

Z Cloudflare (zalecane - rozwiązuje problem IPv6):
```bash
./local/setup-cloudflare.sh                  # jednorazowo
./local/dns-add.sh n8n.mojafirma.pl          # dodaj rekord DNS
ssh mikrus 'mikrus-expose n8n.mojafirma.pl 5678'  # HTTPS
```

> Szczegóły: [docs/cloudflare-domain-setup.md](docs/cloudflare-domain-setup.md) | [docs/ssh-tunnels.md](docs/ssh-tunnels.md)

---

## Opcja AI - niech Claude zrobi to za Ciebie

Masz zainstalowane [Claude Code](https://docs.anthropic.com/en/docs/claude-code)?

```bash
cd mikrus-toolbox
claude
```

Powiedz co chcesz:
- *"Zainstaluj n8n na serwerze mikrus"*
- *"Skonfiguruj backup do Google Drive"*
- *"Sprawdź czy wszystkie kontenery działają"*
- *"Wystaw Dockge pod domeną panel.mojafirma.pl"*

Claude zna ten toolbox (dzięki `AGENTS.md`) i przeprowadzi Cię przez cały proces - DNS, porty, certyfikaty, baza danych.

---

## Kalkulator oszczędności

### Koszt Mikrusa

| Plan | RAM | Dysk | Cena/rok |
|------|-----|------|----------|
| Mikrus 2.1 | 1GB | 10GB | 75 zł |
| Mikrus 3.0 | 2GB | 25GB | 130 zł |
| Mikrus 3.5 | 4GB | 40GB | 197 zł |
| Mikrus 4.1 (2x CPU + 2x IOPS) | 8GB | 80GB | 395 zł |
| Mikrus 4.2 (2x CPU + 2x IOPS) | 16GB | 160GB | 790 zł |

#### Usługi dodatkowe

| Usługa | RAM | Dysk | Cena/rok |
|--------|-----|------|----------|
| MySQL / MariaDB | 512MB | 10GB | 25 zł |
| MySQL / MariaDB | 1024MB | 20GB | 47 zł |
| PostgreSQL | 512MB | 10GB | 29 zł |
| PostgreSQL | 1024MB | 50GB | 119 zł |
| MongoDB | 512MB | 5GB | 25 zł |
| Uptime Kuma | 256MB | 10GB | 15 zł |
| Umami | 512MB | 1GB | 15 zł |
| Domena .pl | - | - | ~50 zł |

### Self-hosted vs. SaaS

| Narzędzie | Zastępuje | Cena SaaS/mies | Na Mikrusie |
|-----------|-----------|----------------|-------------|
| n8n | Zapier Pro | $29-99 | 0 zł |
| Listmonk | Mailchimp (5k kontaktów) | $50+ | 0 zł |
| Typebot | Typeform Pro | $50+ | 0 zł |
| NocoDB | Airtable Pro | $20+ | 0 zł |
| GateFlow | Gumroad (10% prowizji) | $$$ | 0 zł |
| Uptime Kuma | UptimeRobot Pro | $7+ | 0 zł |
| Vaultwarden | 1Password Teams | $8/user | 0 zł |
| Postiz | Buffer Pro | $15+ | 0 zł |
| WordPress | WordPress.com Business | $25+ | 0 zł |
| Stirling-PDF | Adobe Acrobat Pro | $15+ | 0 zł |
| Cap | Loom Business | $15+ | 0 zł |
| FileBrowser | Tiiny.host Pro | $6+ | 0 zł |
| ConvertX | CloudConvert | $9+ | 0 zł |
| Umami | Plausible | $9+ | 0 zł |
| Crawl4AI | ScrapingBee | $49+ | 0 zł |
| **Suma SaaS** | | **~$300+/mies** | |

### Przykład: solopreneur sprzedający kursy

**SaaS-y:** Zapier + Mailchimp + Typeform + UptimeRobot + hosting = **~$142/mies (~7000 zł/rok)**

**Mikrus Toolbox:** Mikrus 3.0 (130 zł) + domena (50 zł) + PostgreSQL (29 zł) = **209 zł/rok**

**Oszczędność: ~6800 zł/rok (97%)**

---

## Wymagania serwera

| Stack | Plan | RAM |
|-------|------|-----|
| Podstawa (Caddy + Dockge) | Mikrus 2.1 | ~100MB |
| + n8n | Mikrus 2.1 | ~500MB |
| + Listmonk + Uptime Kuma | Mikrus 2.1 | ~800MB |
| + Typebot + GateFlow | Mikrus 3.0 | ~1.5GB |
| Pełny stack (10+ narzędzi) | Mikrus 3.0 | ~1.8GB |
| Coolify (PaaS, 280+ apek) | Mikrus 4.1 | ~500-800MB (platforma) |

> Stirling-PDF i Crawl4AI wymagają Mikrus 3.0+ (2GB RAM). Lekka alternatywa: Gotenberg (~150MB).

---

## Coolify - prywatny Heroku/Vercel (Mikrus 4.1+)

Masz **Mikrus 4.1** (8GB RAM, 80GB dysk, 2x CPU)? Zainstaluj [Coolify](https://coolify.io) - open-source PaaS z **280+ aplikacjami** do deploy jednym kliknięciem.

| | |
| :--- | :--- |
| **280+ apek** | WordPress, n8n, Nextcloud, Grafana, Gitea, Supabase, Ollama... |
| **Auto SSL** | Let's Encrypt dla każdej apki |
| **Git push deploy** | Push do GitHub/GitLab = automatyczny deploy |
| **Webowy panel** | Zarządzaj wszystkim przez przeglądarkę |

```bash
./local/deploy.sh coolify --ssh=mikrus
```

> Coolify przejmuje porty 80/443 (Traefik). Nie mieszaj z innymi apkami z toolboxa. Szczegóły: [apps/coolify/README.md](apps/coolify/README.md)

---

## Diagnostyka

```bash
# Czy kontener działa?
ssh mikrus 'docker ps | grep nazwa-uslugi'

# Logi (ostatnie 50 linii)
ssh mikrus 'cd /opt/stacks/nazwa-uslugi && docker compose logs --tail 50'

# Czy port odpowiada? (200/302 = OK)
ssh mikrus 'curl -s -o /dev/null -w "%{http_code}" http://localhost:PORT'

# Zużycie zasobów
ssh mikrus 'docker stats --no-stream'
```

> Dostęp bez domeny: [docs/ssh-tunnels.md](docs/ssh-tunnels.md)

---

## FAQ

**Czy to jest bezpieczne?**
Tak. Usługi w kontenerach Docker, dostęp z zewnątrz tylko przez HTTPS (Caddy/Cytrus), szyfrowane backupy off-site.

**Ile RAMu potrzebuję?**
Mikrus 2.1 (1GB) uciągnie n8n + 2-3 mniejsze usługi. Do pełnego zestawu: Mikrus 3.0 (2GB). Coolify: Mikrus 4.1 (8GB).

**Co z bazą danych?**
Aplikacje wymagające PostgreSQL/MySQL korzystają z bazy Mikrusa (darmowa 200MB lub dedykowana 10GB za 29 zł/rok). Nie instaluj bazy na serwerze - to zjada zasoby.

**Mogę to postawić na innym VPS?**
Tak. Skrypty działają na dowolnym VPS z Dockerem. Mikrus jest zalecany bo jest tani i polski, ale `deploy.sh` działa z każdym serwerem po SSH.

**Jak zaktualizować aplikację?**
Uruchom `deploy.sh` ponownie - skrypt wykryje istniejącą instalację i zaktualizuje obraz Docker. Dane w volumes zostaną zachowane.

---

## Struktura repozytorium

```
local/           → Skrypty użytkownika (deploy, backup, setup, dns)
apps/<app>/      → Instalatory: install.sh + README.md + update.sh
lib/             → Biblioteki (cli-parser, db-setup, domain-setup, health-check)
system/          → Skrypty systemowe (docker, caddy, backup, power-tools)
docs/            → Dokumentacja (Cloudflare, backup, SSH tunele, CLI reference)
tests/           → Testy automatyczne
```

---

## Autor

**Paweł** ([@pavvel11](https://github.com/pavvel11)) - Lazy Engineer

Buduję narzędzia dla solopreneurów, którzy wolą automatyzować niż klikać. Mikrus Toolbox to zestaw, którego sam używam do prowadzenia biznesu.

- [GateFlow](https://github.com/pavvel11/gateflow) - open-source sklep z produktami cyfrowymi
- [Mikrus n8n Manager](https://manager.cytr.us/) - GUI do instalacji n8n na Mikrusie

---

*Self-hosted infrastructure toolkit for solopreneurs. Deploy 25 open-source apps (n8n, WordPress, Listmonk, Typebot, NocoDB, Vaultwarden and more) on a cheap VPS with one command. Replace $300+/month in SaaS subscriptions with a $5/month server.*
