# WordPress - Performance Edition

Najpopularniejszy CMS na świecie, zoptymalizowany pod małe serwery VPS.

## Co jest w środku?

Stack wydajnościowy, który pobija managed hostingi za $10-30/mies:

```
Cytrus/Caddy (host) → Nginx (gzip, FastCGI cache, rate limiting, security)
                        └── PHP-FPM alpine (OPcache + JIT, ondemand workers)
                             └── MySQL (zewnętrzny) lub SQLite
```

| Optymalizacja | Co daje |
|---|---|
| PHP-FPM alpine (nie Apache) | -35MB RAM, mniejszy obraz |
| OPcache + JIT | 2-3x szybszy PHP |
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

- **RAM:** ~200-300MB (WP + Nginx), działa na Mikrus 1.0 (512MB)
- **Dysk:** ~500MB (oba obrazy Docker razem)
- **MySQL:** Shared Mikrus (darmowy) lub własny. SQLite nie wymaga.

## Po instalacji

1. Otwórz stronę → kreator instalacji WordPress
2. Zastosuj optymalizacje wp-config.php:
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

## Dodatkowe optymalizacje (ręczne)

### Redis Object Cache (-70% zapytań do DB)

Jeśli masz Redis (`./local/deploy.sh redis`):
1. Zainstaluj wtyczkę "Redis Object Cache" w panelu WP
2. Aktywuj → automatycznie wykryje Redis na localhost:6379

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
- `docker-compose.yaml`

## RAM Profiling

Skrypt automatycznie wykrywa RAM i dostosowuje PHP-FPM:

| RAM serwera | FPM workers | WP limit | Nginx limit |
|---|---|---|---|
| 512MB | 4 | 192M | 32M |
| 1GB | 8 | 256M | 48M |
| 2GB+ | 15 | 256M | 64M |
