# WordPress - Performance Edition

Najpopularniejszy CMS na świecie, zoptymalizowany pod małe serwery VPS.

## Co jest w środku?

Stack wydajnościowy, który pobija managed hostingi za $10-30/mies:

```
Cytrus/Caddy (host) → Nginx (gzip, FastCGI cache, rate limiting, security)
                        └── PHP-FPM alpine (OPcache + JIT, redis ext, WP-CLI)
                        └── Redis (object cache, bundled)
                             └── MySQL (zewnętrzny) lub SQLite
```

| Optymalizacja | Co daje |
|---|---|
| PHP-FPM alpine (nie Apache) | -35MB RAM, mniejszy obraz |
| OPcache + JIT | 2-3x szybszy PHP |
| Redis Object Cache (bundled) | -70% zapytań do DB (auto-instalacja przez WP-CLI) |
| Nginx FastCGI cache | Cached strony serwowane bez PHP i DB |
| FastCGI cache lock | Ochrona przed thundering herd (1 req do PHP) |
| Gzip compression | -60-80% transferu |
| Open file cache | -80% disk I/O na statycznych plikach |
| Realpath cache 4MB | -30% response time (mniej stat() calls) |
| FPM ondemand + RAM tuning | Dynamiczny profil na podstawie RAM |
| tmpfs /tmp | 20x szybsze I/O dla temp files |
| Security headers | X-Frame, X-Content-Type, Referrer-Policy, Permissions-Policy |
| Rate limiting wp-login | Ochrona brute force bez obciążania PHP |
| Blokada xmlrpc.php | Zamknięty wektor DDoS |
| Blokada user enumeration | ?author=N → 403 |
| WP-Cron → system cron | Brak opóźnień dla odwiedzających |
| Autosave co 5 min | -80% zapisów do DB (domyślne 60s) |
| Blokada wrażliwych plików | wp-config.php, .env, uploads/*.php |
| no-new-privileges | Kontener nie eskaluje uprawnień |
| Log rotation | Logi nie zapchają dysku (max 30MB) |

## Instalacja

### Tryb MySQL (domyślny)

```bash
# Shared MySQL z Mikrusa (darmowy)
./local/deploy.sh wordpress --ssh=hanna --domain-type=cytrus --domain=auto

# Własny MySQL
./local/deploy.sh wordpress --ssh=hanna --db-source=custom --domain-type=cytrus --domain=auto
```

### Tryb SQLite (lekki, bez MySQL)

```bash
WP_DB_MODE=sqlite ./local/deploy.sh wordpress --ssh=hanna --domain-type=cytrus --domain=auto
```

## Wymagania

- **RAM:** ~80-100MB idle (WP + Nginx + Redis), działa na Mikrus 1.0 (512MB)
- **Dysk:** ~550MB (obrazy Docker: WP+redis ext, Nginx, Redis)
- **MySQL:** Shared Mikrus (darmowy) lub własny. SQLite nie wymaga.

## Po instalacji

1. Otwórz stronę → kreator instalacji WordPress
2. Zastosuj optymalizacje wp-config.php + zainstaluj Redis Object Cache:
   ```bash
   ssh hanna 'cd /opt/stacks/wordpress && ./wp-init.sh'
   ```

`wp-init.sh` automatycznie:
- Dodaje fix HTTPS za reverse proxy
- Wyłącza domyślny wp-cron (zastępuje systemowym co 5 min)
- Ustawia limit rewizji (5) i auto-czyszczenie kosza (14 dni)
- Ustawia WP_MEMORY_LIMIT na 256M (admin: 512M)
- Zmienia autosave z 60s na 5 min
- Blokuje edycję plików z panelu WP (security)
- Konfiguruje Redis connection w wp-config.php
- Instaluje i aktywuje plugin Redis Object Cache (WP-CLI)
- Włącza Redis Object Cache drop-in

## Dodatkowa optymalizacja (ręczna)

### Converter for Media (WebP)

Zainstaluj wtyczkę "Converter for Media" → automatyczna konwersja obrazów do WebP.

## FastCGI Cache

Strony są cache'owane przez Nginx na 24h. Cache jest automatycznie pomijany dla:
- Zalogowanych użytkowników
- Panelu admina (`/wp-admin/`)
- API (`/wp-json/`)
- Requestów POST

Ochrona przed thundering herd: gdy wielu użytkowników prosi o tę samą niecachowaną stronę, tylko 1 request trafia do PHP-FPM, reszta czeka na cache. `fastcgi_cache_background_update` serwuje stale content podczas odświeżania.

Wyczyść cache po aktualizacji treści/wtyczek:
```bash
ssh hanna 'cd /opt/stacks/wordpress && ./flush-cache.sh'
```

Header `X-FastCGI-Cache` w odpowiedzi HTTP pokazuje status: `HIT`, `MISS`, `BYPASS`.

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
./local/setup-backup.sh hanna
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
