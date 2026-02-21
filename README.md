# 🧰 Mikrus Toolbox

**26 self-hosted aplikacji. Jeden serwer. Zero abonamentów.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Apps: 26+](https://img.shields.io/badge/Apps-26%2B-blue.svg)](#-26-aplikacji-w-arsenale)
[![Works on any VPS](https://img.shields.io/badge/Works%20on-any%20VPS-orange.svg)](#mogę-to-postawić-na-innym-vps)
[![GitHub Stars](https://img.shields.io/github/stars/jurczykpawel/mikrus-toolbox?style=social)](https://github.com/jurczykpawel/mikrus-toolbox)

Zamień tani polski VPS ([mikr.us](https://mikr.us/?r=pavvel)) w pełną infrastrukturę firmy — automatyzacja, mailing, analityka, CRM, sklep z produktami cyfrowymi — za ~20 zł/mies zamiast ~7000 zł/rok w SaaS-ach.

[📖 Dokumentacja](docs/) | [🐛 Zgłoś problem](https://github.com/jurczykpawel/mikrus-toolbox/issues) | [💬 Dyskusje](https://github.com/jurczykpawel/mikrus-toolbox/discussions)

```bash
git clone https://github.com/jurczykpawel/mikrus-toolbox.git
cd mikrus-toolbox
./local/deploy.sh n8n        # → n8n działa na Twoim serwerze
```

Każda aplikacja to jeden `deploy.sh` — skrypt pyta o domenę, bazę danych, sprawdza zasoby serwera i instaluje **zoptymalizowaną wersję** pod małe VPS-y.

---

## 🚀 Dlaczego Mikrus Toolbox?

- **Jedna komenda = działająca aplikacja** — `deploy.sh` sprawdza RAM, dysk, porty, instaluje bazę danych, konfiguruje domenę z HTTPS i weryfikuje, czy wszystko działa
- **Integracja z AI / MCP** — powiedz Claude'owi *"Zainstaluj n8n na serwerze"* i patrz jak sam deployuje, konfiguruje DNS i sprawdza logi
- **Konfiguracje zoptymalizowane pod produkcję** — memory limity, health checki, auto-restart, logi bez zapychania dysku
- **Zero platform overhead** — żadnego Kubernetes, Terraform ani panelu za $20/mies. Czysty Docker Compose + Bash
- **26 przetestowanych aplikacji** — od automatyzacji (n8n) przez newsletter (Listmonk) po sklep z produktami cyfrowymi (GateFlow)

---

## 🎯 Dla kogo?

Dla **solopreneurów, freelancerów i małych firm**, które:

- Płacą za Zapier, Mailchimp, Airtable, Typeform i widzą, jak rachunki rosną z każdym kontaktem
- Chcą mieć dane na **własnym serwerze** — nie u Google'a, nie w USA
- Wolą zainwestować raz w konfigurację, niż płacić abonament do końca życia
- Szukają **dźwigni** — automatyzacji, która pracuje 24/7 bez opłat za "execution"

> Nie chcesz wpisywać komend? Sprawdź **[Mikrus n8n Manager](https://manager.cytr.us/)** — GUI, które zainstaluje n8n jednym kliknięciem.

---

## 📑 Spis treści

- [Dlaczego Mikrus Toolbox?](#-dlaczego-mikrus-toolbox)
- [Dla kogo?](#-dla-kogo)
- [26 aplikacji](#-26-aplikacji-w-arsenale)
- [Jak to działa razem](#-jak-to-działa-razem)
- [Szybki start](#-szybki-start)
- [Opcja AI / MCP](#-opcja-ai--mcp)
- [Domeny i HTTPS](#-domeny-i-https)
- [Kalkulator oszczędności](#-kalkulator-oszczędności)
- [Wymagania serwera](#-wymagania-serwera)
- [Coolify](#-coolify---prywatny-herokuvercel-mikrus-41)
- [Diagnostyka](#-diagnostyka)
- [FAQ](#-faq)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [Wsparcie / Społeczność](#-wsparcie--społeczność)
- [Struktura repozytorium](#-struktura-repozytorium)
- [Tech Stack](#️-tech-stack)
- [Star History](#-star-history)
- [Podziękowania](#-podziękowania)
- [Autor](#-autor)
- [Licencja](#-licencja)

---

## 🛠️ 26 aplikacji w arsenale

### Automatyzacja i operacje

| Aplikacja | Zastępuje | Co robi |
| :--- | :--- | :--- |
| [**n8n**](apps/n8n/) | Zapier / Make | **Mózg firmy.** Łączy wszystko ze wszystkim — CRM, maile, płatności, API. |
| [**Dockge**](apps/dockge/) | Portainer | **Panel Docker** do zarządzania kontenerami przez przeglądarkę. |
| [**Uptime Kuma**](apps/uptime-kuma/) | UptimeRobot | **Monitoring** stron i usług z alertami na telefon. |
| [**ntfy**](apps/ntfy/) | Pushover | **Serwer powiadomień push.** Wysyłaj alerty z n8n na telefon. |
| [**Redis**](apps/redis/) | - | **Cache.** Przyspiesza n8n, WordPress i inne aplikacje. |
| [**Crawl4AI**](apps/crawl4ai/) | ScrapingBee | **AI web scraper** z REST API. Markdown, LLM extraction, JS rendering. |
| [**PicoClaw**](apps/picoclaw/) | OpenClaw | **Osobisty asystent AI** (Telegram/Discord/Slack). Ultra-lekki (~10MB, 64MB RAM). 🔒 Max izolacja. |
| [**MCP Docker**](apps/mcp-docker/) | - | **Most AI-serwer.** Pozwól Claude/Cursor zarządzać kontenerami. |
| [**MinIO**](apps/minio/) | AWS S3 | **Self-hosted object storage** (S3-compatible). |

### Marketing i sprzedaż

| Aplikacja | Zastępuje | Co robi |
| :--- | :--- | :--- |
| [**GateFlow**](apps/gateflow/) | Gumroad / EasyCart | **Sklep z produktami cyfrowymi.** 0 zł/mies, 0% prowizji. Lejki, kupony, Omnibus EU. |
| [**Listmonk**](apps/listmonk/) | Mailchimp | **Newsletter** na miliony maili za grosze (przez Amazon SES lub SMTP). |
| [**Typebot**](apps/typebot/) | Typeform | **Chatboty i formularze.** Zbieraj leady, rób ankiety, sprzedawaj w rozmowie. |
| [**Postiz**](apps/postiz/) | Buffer / Hootsuite | **Planuj posty** na X, LinkedIn, Instagram, Facebook, TikTok. ⚠️ Wymaga 4GB+ RAM. |
| [**Cap**](apps/cap/) | Loom | **Nagrywaj ekran** i udostępniaj wideo. Tutoriale, async communication. |
| [**Umami**](apps/umami/) | Google Analytics | **Analityka bez cookies,** bez RODO-paniki, z szacunkiem do prywatności. |
| [**Cookie Hub**](apps/cookie-hub/) | Cookiebot | **Centralny serwer zgód RODO** dla wszystkich Twoich stron. |
| [**FileBrowser**](apps/filebrowser/) | Dropbox / Tiiny.host | **Prywatny dysk** z UI + hosting plików i landing page'y. |

### Biuro i produktywność

| Aplikacja | Zastępuje | Co robi |
| :--- | :--- | :--- |
| [**AFFiNE**](apps/affine/) | Notion / Miro | Baza wiedzy z dokumentami, tablicami i bazą danych. Open-source. |
| [**WordPress**](apps/wordpress/) | WordPress.com | **Performance Edition:** Nginx + PHP-FPM + Redis Object Cache, auto-tuning. |
| [**NocoDB**](apps/nocodb/) | Airtable | **Baza danych** z interfejsem arkusza kalkulacyjnego. CRM, projekty, zamówienia. |
| [**Stirling-PDF**](apps/stirling-pdf/) | Adobe Acrobat | **Edycja, łączenie, podpisywanie** PDF-ów w przeglądarce. |
| [**Gotenberg**](apps/gotenberg/) | - | **API do konwersji dokumentów** (HTML/DOCX/ODT → PDF). Lekki: ~150MB RAM. |
| [**ConvertX**](apps/convertx/) | CloudConvert | **Konwerter 800+ formatów** plików w przeglądarce. |
| [**Vaultwarden**](apps/vaultwarden/) | 1Password | **Menedżer haseł** dla całej firmy. Kompatybilny z Bitwarden. |
| [**LinkStack**](apps/linkstack/) | Linktree | **Wizytówka "Link in Bio"** z panelem admina. |
| [**LittleLink**](apps/littlelink/) | Linktree | **Wizytówka "Link in Bio"** — wersja ultra-lekka, czysty HTML. |

> Każda aplikacja ma swój `README.md` z dokumentacją, wymaganiami i opcjami konfiguracji.

---

## 🔗 Jak to działa razem

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

1. **Typebot** — klient rozmawia z botem, który bada potrzeby
2. **GateFlow** — bot kieruje do płatności za e-booka
3. **n8n** — wykrywa płatność i automatycznie: dodaje klienta do CRM (**NocoDB**), wysyła e-booka mailem, wystawia fakturę, zapisuje do newslettera (**Listmonk**)
4. **Umami** — śledzi konwersję

Wszystko na Twoim serwerze. **Zero opłat za "execution". Zero limitów.**

---

## ⚡ Szybki start

### Wymagania

- **Serwer VPS** — [Mikrus](https://mikr.us/?r=pavvel) 3.0+ (1GB RAM, 10GB dysk, od 20 zł/mies)
- **Domena** — np. z [OVH](https://www.ovhcloud.com/pl/domains/) (od ~12 zł/rok)
- **Terminal** z dostępem SSH

> **🎁 1 miesiąc gratis!** Kup Mikrusa przez [ten link](https://mikr.us/?r=pavvel) (reflink), wybierz ofertę (zalecamy 3.0+) i miesiąc gratis zostanie automatycznie doliczony do zamówienia.

### 1. Konfiguracja SSH

```bash
# Linux / macOS
bash <(curl -s https://raw.githubusercontent.com/jurczykpawel/mikrus-toolbox/main/local/setup-ssh.sh)

# Windows (PowerShell)
iwr -useb https://raw.githubusercontent.com/jurczykpawel/mikrus-toolbox/main/local/setup-ssh.ps1 | iex
```

Skrypt zapyta o dane z maila od Mikrusa (host, port, hasło) i skonfiguruje klucz SSH + alias.

### 2. Pobierz toolbox

```bash
git clone https://github.com/jurczykpawel/mikrus-toolbox.git
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

`deploy.sh` zadba o wszystko — sprawdzi zasoby serwera, zapyta o domenę i bazę danych, zainstaluje aplikację i zweryfikuje czy działa.

### 5. Backup — zrób to od razu

```bash
./local/setup-backup.sh     # Szyfrowany backup do Google Drive / Dropbox
```

> Szczegóły: [docs/backup.md](docs/backup.md)

---

## 🤖 Opcja AI / MCP

Mikrus Toolbox ma wbudowany **serwer MCP** (Model Context Protocol) — pozwala asystentom AI (Claude Desktop, Claude Code, Cursor) zarządzać Twoim serwerem przez naturalny język.

### Dlaczego to zmienia grę?

Zamiast wpisywać komendy, **mówisz co chcesz** — AI sam dobiera aplikację, sprawdza zasoby, konfiguruje bazę danych, ustawia domenę i weryfikuje deployment.

### Konfiguracja Claude Desktop

Dodaj do `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "mikrus-toolbox": {
      "command": "node",
      "args": ["/sciezka/do/mikrus-toolbox/mcp-server/dist/index.js"]
    }
  }
}
```

Przed pierwszym uruchomieniem:

```bash
cd mikrus-toolbox/mcp-server
npm install && npm run build
```

### Konfiguracja Claude Code

Wystarczy otworzyć repozytorium — Claude Code automatycznie czyta `AGENTS.md` i zna cały toolbox:

```bash
cd mikrus-toolbox
claude
```

### Przykładowe komendy

| Co mówisz | Co AI robi |
| :--- | :--- |
| *"Zainstaluj n8n na serwerze"* | Sprawdza RAM, pyta o bazę danych, deployuje, konfiguruje domenę |
| *"Skonfiguruj backup do Google Drive"* | Prowadzi przez setup rclone i cron |
| *"Sprawdź czy wszystkie kontenery działają"* | Łączy się po SSH, sprawdza `docker ps`, raportuje problemy |
| *"Wystaw Dockge pod domeną panel.mojafirma.pl"* | Konfiguruje DNS przez Cloudflare, ustawia HTTPS przez Caddy |
| *"Postaw mi sklep z produktami cyfrowymi"* | Prowadzi przez konfigurację Supabase, deployuje GateFlow |
| *"Co mogę zainstalować?"* | Wyświetla 26+ aplikacji z opisami i wymaganiami |

### 8 narzędzi MCP

| Narzędzie | Opis |
| :--- | :--- |
| `setup_server` | Konfiguracja SSH lub test połączenia |
| `list_apps` | Lista 26+ aplikacji z metadanymi (RAM, DB, porty) |
| `deploy_app` | Deploy przetestowanej aplikacji z toolboxa |
| `deploy_custom_app` | Deploy **dowolnej** aplikacji Docker (AI generuje compose) |
| `deploy_site` | Deploy lokalnego projektu (strona, Node.js, Python) |
| `setup_domain` | Konfiguracja darmowej subdomeny Cytrus |
| `setup_backup` | Konfiguracja automatycznych backupów |
| `server_status` | Status serwera: kontenery, RAM, dysk, porty |

> Szczegóły: [mcp-server/README.md](mcp-server/README.md)

---

## 🌐 Domeny i HTTPS

Dwie opcje:

| | Cytrus (łatwiej) | Caddy (więcej kontroli) |
|---|---|---|
| Konfiguracja | Panel Mikrusa | Terminal |
| SSL | Automatyczny | Let's Encrypt |
| Jak | [Panel → Domeny](https://mikr.us/panel/?a=hosting_domeny) | `ssh mikrus 'mikrus-expose domena.pl 5678'` |

Z **Cloudflare** (zalecane — rozwiązuje problem IPv6):

```bash
./local/setup-cloudflare.sh                  # jednorazowo
./local/dns-add.sh n8n.mojafirma.pl          # dodaj rekord DNS
ssh mikrus 'mikrus-expose n8n.mojafirma.pl 5678'  # HTTPS
```

> Szczegóły: [docs/cloudflare-domain-setup.md](docs/cloudflare-domain-setup.md) | [docs/ssh-tunnels.md](docs/ssh-tunnels.md)

---

## 💰 Kalkulator oszczędności

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
| n8n | Zapier Pro | $29-99 | **0 zł** |
| Listmonk | Mailchimp (5k kontaktów) | $50+ | **0 zł** |
| Typebot | Typeform Pro | $50+ | **0 zł** |
| NocoDB | Airtable Pro | $20+ | **0 zł** |
| GateFlow | Gumroad (10% prowizji) | $$$ | **0 zł** |
| Uptime Kuma | UptimeRobot Pro | $7+ | **0 zł** |
| Vaultwarden | 1Password Teams | $8/user | **0 zł** |
| Postiz | Buffer Pro | $15+ | **0 zł** |
| WordPress | WordPress.com Business | $25+ | **0 zł** |
| Stirling-PDF | Adobe Acrobat Pro | $15+ | **0 zł** |
| Cap | Loom Business | $15+ | **0 zł** |
| FileBrowser | Tiiny.host Pro | $6+ | **0 zł** |
| ConvertX | CloudConvert | $9+ | **0 zł** |
| Umami | Plausible | $9+ | **0 zł** |
| Crawl4AI | ScrapingBee | $49+ | **0 zł** |
| **Suma SaaS** | | **~$300+/mies** | |

### Przykład: solopreneur sprzedający kursy

**SaaS-y:** Zapier + Mailchimp + Typeform + UptimeRobot + hosting = **~$142/mies (~7000 zł/rok)**

**Mikrus Toolbox:** Mikrus 3.0 (130 zł) + domena (50 zł) + PostgreSQL (29 zł) = **209 zł/rok**

**Oszczędność: ~6800 zł/rok (97%)**

---

## 📊 Wymagania serwera

| Stack | Plan | RAM |
|-------|------|-----|
| Podstawa (Caddy + Dockge) | Mikrus 2.1 | ~100MB |
| + n8n | Mikrus 2.1 | ~500MB |
| + Listmonk + Uptime Kuma | Mikrus 2.1 | ~800MB |
| + Typebot + GateFlow | Mikrus 3.0 | ~1.5GB |
| Pełny stack (10+ narzędzi) | Mikrus 3.0 | ~1.8GB |
| Coolify (PaaS, 280+ apek) | Mikrus 4.1 | ~500-800MB (platforma) |

> **Stirling-PDF** i **Crawl4AI** wymagają Mikrus 3.0+ (2GB RAM). Lekka alternatywa: **Gotenberg** (~150MB).

---

## ☁️ Coolify — prywatny Heroku/Vercel (Mikrus 4.1+)

Masz **Mikrus 4.1** (8GB RAM, 80GB dysk, 2x CPU)? Zainstaluj [Coolify](https://coolify.io) — open-source PaaS z **280+ aplikacjami** do deploy jednym kliknięciem.

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

## 🔍 Diagnostyka

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

## ❓ FAQ

**Czy to jest bezpieczne?**
Tak. Usługi w kontenerach Docker, dostęp z zewnątrz tylko przez **HTTPS** (Caddy z certyfikatami Let's Encrypt), szyfrowane backupy off-site.

**Ile RAMu potrzebuję?**
Mikrus 2.1 (1GB) uciągnie n8n + 2-3 mniejsze usługi. Do pełnego zestawu: Mikrus 3.0 (2GB). Coolify: Mikrus 4.1 (8GB).

**Co z bazą danych?**
Trzy opcje: **darmowa baza Mikrusa** (współdzielona, 200MB), **dedykowana baza Mikrusa** (10GB za 29 zł/rok), lub **bundled baza** wbudowana w kontener (np. WordPress z SQLite, Redis w kontenerze). `deploy.sh` poprowadzi Cię przez wybór.

**Mogę to postawić na innym VPS?**
Tak. Skrypty działają na **dowolnym VPS z Dockerem**. Mikrus jest zalecany bo jest tani i polski, ale `deploy.sh` działa z każdym serwerem po SSH. Jeśli masz Hetznera, DigitalOcean lub innego dostawcę — sprawdź [StackPilot](https://github.com/jurczykpawel/stackpilot), angielskojęzyczną wersję tego toolboxa zoptymalizowaną pod dowolny VPS.

**Jak zaktualizować aplikację?**
Uruchom `deploy.sh` ponownie — skrypt wykryje istniejącą instalację i zaktualizuje obraz Docker. Dane w volumes zostaną zachowane.

---

## 🗺️ Roadmap

### Zrobione

- [x] **26 przetestowanych aplikacji** — od n8n po GateFlow
- [x] **Serwer MCP** — zarządzanie serwerem przez AI (Claude Desktop, Claude Code, Cursor)
- [x] **Integracja z Cloudflare** — automatyczna konfiguracja DNS
- [x] **Bundled bazy danych** — Redis i SQLite wbudowane w kontenery
- [x] **System backupów** — cron na serwerze + rclone do chmury (Google Drive, Dropbox, S3)
- [x] **Deploy lokalnych projektów** — `deploy_site` dla stron statycznych, Node.js, Python
- [x] **WordPress Performance Edition** — Nginx + PHP-FPM + Redis Object Cache z auto-tuningiem
- [x] **Deploy dowolnej aplikacji Docker** — `deploy_custom_app` generuje compose z AI

### W trakcie

- [ ] **Hosting stron statycznych i PHP** — `add-static-hosting.sh` i `add-php-hosting.sh`
- [ ] **Synchronizacja między projektami** — wyrównanie funkcji z [StackPilot](https://github.com/jurczykpawel/stackpilot)

### W planach

- [ ] **GUI dashboard** — webowy panel do zarządzania aplikacjami bez terminala
- [ ] **Więcej aplikacji** — Nextcloud, Grafana, Plausible, Gitea
- [ ] **One-click stacks** — gotowe zestawy (np. "solopreneur stack" = n8n + Listmonk + GateFlow + Uptime Kuma)
- [ ] **Automatyczne aktualizacje** — Watchtower / Diun z powiadomieniami
- [ ] **Monitoring zasobów** — alerty gdy RAM/dysk się kończą

> Masz pomysł? [Otwórz Issue](https://github.com/jurczykpawel/mikrus-toolbox/issues) lub [dyskusję](https://github.com/jurczykpawel/mikrus-toolbox/discussions).

---

## 🤝 Contributing

Każdy wkład jest mile widziany — od poprawki literówki po nową aplikację!

- **🐛 Znalazłeś buga?** — [Otwórz Issue](https://github.com/jurczykpawel/mikrus-toolbox/issues) z logami i opisem
- **💡 Masz pomysł na aplikację?** — [Otwórz Issue](https://github.com/jurczykpawel/mikrus-toolbox/issues) z opisem use case'u
- **🔧 Chcesz dodać kod?** — Fork → branch → PR. Przetestuj na prawdziwym serwerze
- **📝 Dokumentacja** — poprawki, tłumaczenia, lepsze opisy

Szczegóły: [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 💬 Wsparcie / Społeczność

- **Pytania i problemy** — [GitHub Issues](https://github.com/jurczykpawel/mikrus-toolbox/issues)
- **Dyskusje, pomysły, showcase** — [GitHub Discussions](https://github.com/jurczykpawel/mikrus-toolbox/discussions)
- **Bezpieczeństwo** — znalazłeś podatność? Nie twórz publicznego Issue. Użyj [GitHub Security Advisories](https://github.com/jurczykpawel/mikrus-toolbox/security/advisories/new)

Jeśli Mikrus Toolbox jest dla Ciebie przydatny, zostaw ⭐ na [GitHubie](https://github.com/jurczykpawel/mikrus-toolbox) — to pomaga innym go znaleźć.

---

## 📁 Struktura repozytorium

```
local/           → Skrypty użytkownika (deploy, backup, setup, dns)
apps/<app>/      → Instalatory: install.sh + README.md + update.sh
lib/             → Biblioteki (cli-parser, db-setup, domain-setup, health-check)
system/          → Skrypty systemowe (docker, caddy, backup, power-tools)
mcp-server/      → Serwer MCP (TypeScript, Model Context Protocol)
docs/            → Dokumentacja (Cloudflare, backup, SSH tunele, CLI reference)
tests/           → Testy automatyczne
```

---

## 🛠️ Tech Stack

| Technologia | Rola |
| :--- | :--- |
| **Bash** | Skrypty instalacyjne, deploy, backup, diagnostyka |
| **Docker / Docker Compose** | Konteneryzacja aplikacji |
| **Caddy** | Reverse proxy z automatycznym HTTPS (Let's Encrypt) |
| **TypeScript** | Serwer MCP (Model Context Protocol) |
| **SSH / rsync** | Zdalne zarządzanie serwerem i synchronizacja plików |
| **Cloudflare API** | Automatyczna konfiguracja DNS |
| **rclone** | Szyfrowane backupy do chmury (Google Drive, Dropbox, S3) |

---

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=jurczykpawel/mikrus-toolbox&type=Date)](https://star-history.com/#jurczykpawel/mikrus-toolbox&Date)

---

## 🙏 Podziękowania

- [Mikrus](https://mikr.us) — tani polski VPS, który zainspirował ten projekt
- [Caddy](https://caddyserver.com/) — reverse proxy z automatycznym HTTPS
- [Docker](https://www.docker.com/) — konteneryzacja, która to wszystko umożliwia
- [Model Context Protocol](https://modelcontextprotocol.io/) — standard integracji AI z narzędziami
- Wszystkim twórcom open-source aplikacji, które ten toolbox instaluje

---

## 👤 Autor

**Paweł** ([@jurczykpawel](https://github.com/jurczykpawel)) — Lazy Engineer

Buduję narzędzia dla solopreneurów, którzy wolą automatyzować niż klikać. Mikrus Toolbox to zestaw, którego sam używam do prowadzenia biznesu.

- [me.techskills.academy](https://me.techskills.academy) — moje linki
- [GateFlow](https://github.com/jurczykpawel/gateflow) — open-source sklep z produktami cyfrowymi
- [Mikrus n8n Manager](https://manager.cytr.us/) — GUI do instalacji n8n na Mikrusie

---

## 📄 Licencja

MIT — zobacz [LICENSE](LICENSE)

---

*Self-hosted infrastructure toolkit for solopreneurs. Deploy 26 open-source apps (n8n, WordPress, Listmonk, Typebot, NocoDB, Vaultwarden and more) on a cheap VPS with one command. Replace $300+/month in SaaS subscriptions with a $5/month server.*
