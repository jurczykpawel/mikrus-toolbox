# WordPress - Performance Edition

Najpopularniejszy CMS na świecie, zoptymalizowany pod małe serwery VPS.

**TTFB ~200ms** z cache (vs 2-5s na typowych hostingach). Zero konfiguracji — wszystko automatyczne.

## Co jest w środku?

Stack wydajnościowy, który pobija managed hostingi za $10-30/mies:

```
Cytrus/Caddy (host) → Nginx (gzip, FastCGI cache, rate limiting, security)
                        └── PHP-FPM alpine (OPcache + JIT, redis ext, WP-CLI)
                        └── Redis (object cache, bundled)
                             └── MySQL (zewnętrzny) lub SQLite
```

### Optymalizacje (automatyczne, zero konfiguracji)

| Optymalizacja | Co daje | Cena u konkurencji |
|---|---|---|
| Nginx FastCGI cache + auto-purge | Cached strony ~200ms TTFB (bez PHP i DB) | $10-20/mies (Kinsta, WP Engine) |
| Redis Object Cache (drop-in) | -70% zapytań do DB | $10-30/mies (Redis addon) |
| PHP-FPM alpine (nie Apache) | -35MB RAM, mniejszy obraz | standard na drogich hostach |
| OPcache + JIT | 2-3x szybszy PHP | standard na drogich hostach |
| Nginx Helper plugin (auto-purge) | Cache czyszczony przy edycji treści | wbudowane w Kinsta/WP Engine |
| WooCommerce-aware cache rules | Koszyk/checkout omija cache, reszta cachowana | premium plugin ($49/rok) |
| session.cache_limiter bypass | Cache działa z Breakdance/Elementor (session_start fix) | know-how za $$$ |
| fastcgi_ignore_headers | Nginx cachuje mimo Set-Cookie z page builderów | know-how za $$$ |
| FastCGI cache lock | Ochrona przed thundering herd (1 req do PHP) | Cloudflare Enterprise |
| Gzip compression | -60-80% transferu | free |
| Open file cache | -80% disk I/O na statycznych plikach | standard |
| Realpath cache 4MB | -30% response time (mniej stat() calls) | know-how |
| FPM ondemand + RAM tuning | Dynamiczny profil na podstawie RAM serwera | managed hosting |
| tmpfs /tmp | 20x szybsze I/O dla temp files | know-how |
| Security headers | X-Frame, X-Content-Type, Referrer-Policy, Permissions-Policy | standard |
| Rate limiting wp-login | Ochrona brute force bez obciążania PHP | plugin ($) |
| Blokada xmlrpc.php | Zamknięty wektor DDoS | plugin ($) |
| Blokada user enumeration | ?author=N → 403 | plugin ($) |
| WP-Cron → system cron | Brak opóźnień dla odwiedzających | know-how |
| Autosave co 5 min | -80% zapisów do DB (domyślne 60s) | know-how |
| Blokada wrażliwych plików | wp-config.php, .env, uploads/*.php | plugin ($) |
| no-new-privileges | Kontener nie eskaluje uprawnień | Docker know-how |
| Log rotation | Logi nie zapchają dysku (max 30MB) | standard |

**Łączna wartość tych optymalizacji: $20-50/mies na managed hostingu.**
Na Mikrusie: **$2.50/mies** (Mikrus 2.1, 1GB RAM).

### Benchmark: Mikrus vs typowy shared hosting

| Metryka | Shared hosting | Mikrus WP |
|---|---|---|
| TTFB (strona główna) | 800-3000ms | **~200ms** (cache HIT) |
| TTFB (cold, bez cache) | 2000-5000ms | **300-400ms** |
| TTFB z Breakdance/Elementor | 2000-5000ms (session kill cache) | **~200ms** (session bypass) |
| Redis Object Cache | brak / addon $10/mies | wbudowany |
| Auto cache purge | brak / plugin | Nginx Helper (auto) |
| WooCommerce + cache | ręczna konfiguracja | auto (skip rules) |

## Instalacja

### Tryb MySQL (domyślny)

```bash
# Shared MySQL z Mikrusa (darmowy)
./local/deploy.sh wordpress --ssh=mikrus --domain-type=cytrus --domain=auto

# Własny MySQL
./local/deploy.sh wordpress --ssh=mikrus --db-source=custom --domain-type=cytrus --domain=auto
```

### Tryb SQLite (lekki, bez MySQL)

```bash
WP_DB_MODE=sqlite ./local/deploy.sh wordpress --ssh=mikrus --domain-type=cytrus --domain=auto
```

### Redis (external vs bundled)

Domyślnie auto-detekcja: jeśli port 6379 nasłuchuje na serwerze, WordPress łączy się z istniejącym Redis (bez nowego kontenera). W przeciwnym razie bundluje `redis:alpine`.

```bash
# Wymuś bundled Redis (nawet gdy istnieje external)
WP_REDIS=bundled ./local/deploy.sh wordpress --ssh=mikrus

# Wymuś external Redis (host)
WP_REDIS=external ./local/deploy.sh wordpress --ssh=mikrus

# External Redis z hasłem
REDIS_PASS=tajneHaslo WP_REDIS=external ./local/deploy.sh wordpress --ssh=mikrus

# Auto-detekcja (domyślne)
./local/deploy.sh wordpress --ssh=mikrus
```

## Wymagania

- **RAM:** ~80-100MB idle (WP + Nginx + Redis), działa na Mikrus 2.1 (1GB RAM)
- **Dysk:** ~550MB (obrazy Docker: WP+redis ext, Nginx, Redis)
- **MySQL:** Shared Mikrus (darmowy) lub własny. SQLite nie wymaga.

## Po instalacji

1. Otwórz stronę → kreator instalacji WordPress (jedyny ręczny krok)

Optymalizacje `wp-init.sh` uruchamiają się **automatycznie** po kreatorze. Nie trzeba nic robić ręcznie.

`wp-init.sh` automatycznie:
- Generuje `wp-config-performance.php` (HTTPS fix, limity, Redis config)
- Instaluje i aktywuje plugin **Redis Object Cache** + włącza drop-in
- Instaluje i aktywuje plugin **Nginx Helper** (auto-purge FastCGI cache)
- Konfiguruje Nginx Helper: file-based purge, purge przy edycji/usunięciu/komentarzu
- Dodaje systemowy cron co 5 min (zastępuje wp-cron)
- Czyści FastCGI cache po konfiguracji

Jeśli WordPress nie jest jeszcze zainicjalizowany, wp-init.sh ustawia retry cron (co minutę, max 30 prób) i dokończy konfigurację automatycznie.

## FastCGI Cache

Strony są cache'owane przez Nginx na 24h. **TTFB ~200ms** z cache vs 300-3000ms bez.

### Automatyczny purge (Nginx Helper)

Plugin Nginx Helper automatycznie czyści cache gdy:
- Edytujesz/publikujesz stronę lub post
- Usuwasz stronę lub post
- Ktoś dodaje/usuwa komentarz
- Aktualizujesz menu lub widgety

Tryb: **file-based purge** (unlink_files) — najszybszy, bez HTTP requests.

### Skip cache rules

Cache jest automatycznie pomijany dla:
- Zalogowanych użytkowników (cookie `wordpress_logged_in`)
- Panelu admina (`/wp-admin/`)
- API (`/wp-json/`)
- Requestów POST
- **WooCommerce:** koszyk, checkout, my-account (cookie `woocommerce_cart_hash`)

### Kompatybilność z page builderami

Breakdance, Elementor i inne page buildery wywołują `session_start()`, co domyślnie wysyła `Cache-Control: no-store` i blokuje cachowanie. Nasze rozwiązanie:
- `session.cache_limiter =` — PHP nie wysyła nagłówka Cache-Control
- `fastcgi_ignore_headers Cache-Control Expires Set-Cookie` — Nginx cachuje mimo Set-Cookie

**Efekt:** strony z Breakdance cachowane normalnie (~200ms vs 2-5s na innych hostingach).

### Thundering herd protection

Gdy wielu użytkowników prosi o tę samą niecachowaną stronę, tylko 1 request trafia do PHP-FPM, reszta czeka na cache. `fastcgi_cache_background_update` serwuje stale content podczas odświeżania.

### Ręczne czyszczenie cache

```bash
ssh mikrus 'cd /opt/stacks/wordpress && ./flush-cache.sh'
```

Header `X-FastCGI-Cache` w odpowiedzi HTTP pokazuje status: `HIT`, `MISS`, `BYPASS`.

## Dodatkowa optymalizacja (ręczna)

### Cloudflare Edge Cache

Przy deploy z `--domain-type=cloudflare`, optymalizacja zone i cache rules uruchamia się **automatycznie**.

Ręczne uruchomienie (np. po zmianie domeny):
```bash
./local/setup-cloudflare-optimize.sh wp.mojadomena.pl --app=wordpress
```

Co ustawia:
- **Zone:** SSL Flexible, Brotli, Always HTTPS, HTTP/2+3, Early Hints
- **Bypass cache:** `/wp-admin/*`, `/wp-login.php`, `/wp-json/*`, `/wp-cron.php`
- **Cache 1 rok:** `/wp-content/uploads/*` (media), `/wp-includes/*` (core static)
- **Cache 1 tydzień:** `/wp-content/themes/*`, `/wp-content/plugins/*` (assets)

Cloudflare edge cache działa **nad** Nginx FastCGI cache - statyki serwowane z CDN bez dotykania serwera. Dla stron HTML FastCGI cache jest lepszy (zna kontekst zalogowanego usera).

### Converter for Media (WebP)

Zainstaluj wtyczkę "Converter for Media" → automatyczna konwersja obrazów do WebP.

## Security

| Zabezpieczenie | Opis |
|---|---|
| Rate limiting wp-login.php | 1 req/s z burst 3 (429 Too Many Requests) |
| xmlrpc.php zablokowany | deny all (wektor DDoS i brute force) |
| User enumeration blocked | ?author=N → 403 |
| Edycja plików z panelu WP | Zablokowana (DISALLOW_FILE_EDIT) |
| PHP w uploads/ | Zablokowane (deny all) |
| no-new-privileges | Kontener nie może eskalować uprawnień |
| Security headers | X-Frame, X-Content-Type, Referrer-Policy, Permissions-Policy |

## Backup

```bash
./local/setup-backup.sh mikrus
```

Dane w `/opt/stacks/wordpress/`:
- `wp-content/` - wtyczki, motywy, uploady, baza SQLite
- `config/` - konfiguracja PHP/Nginx/FPM
- `redis-data/` - cache Redis
- `docker-compose.yaml`

## RAM Profiling

Skrypt automatycznie wykrywa RAM i dostosowuje PHP-FPM:

| RAM serwera | FPM workers | WP limit | Nginx limit |
|---|---|---|---|
| 512MB | 4 | 192M | 32M |
| 1GB | 8 | 256M | 48M |
| 2GB+ | 15 | 256M | 64M |

Redis: 64MB maxmemory (allkeys-lru) + 96MB Docker limit dla wszystkich profili.
