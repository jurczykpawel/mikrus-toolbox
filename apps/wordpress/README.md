# WordPress - Blog, Sklep, Portfolio

Najpopularniejszy CMS na świecie. Postawisz blog, sklep (WooCommerce), portfolio - cokolwiek.

## Dlaczego WordPress na Mikrusie?

| Cecha | Mikrus + WordPress | Hosting współdzielony | WordPress.com |
|-------|-------------------|----------------------|---------------|
| Cena | Od 0 zł/mies. | Od 10-30 zł/mies. | Od $4/mies. |
| Kontrola | Pełna | Ograniczona | Minimalna |
| Wtyczki | Wszystkie | Większość | Tylko płatny plan |
| SSL | Automatyczny (Cytrus) | Zależy | Tak |

## Instalacja

### Tryb MySQL (domyślny - zalecany)

```bash
# Shared MySQL z Mikrusa (darmowy)
./local/deploy.sh wordpress --ssh=hanna --domain-type=cytrus --domain=auto

# Własny MySQL
./local/deploy.sh wordpress --ssh=hanna --db-source=custom --domain-type=cytrus --domain=auto
```

### Tryb SQLite (lekki, bez MySQL)

Idealny dla prostych blogów na Mikrus 1.0 (512MB RAM). Nie wymaga bazy MySQL.

```bash
WP_DB_MODE=sqlite ./local/deploy.sh wordpress --ssh=hanna --domain-type=cytrus --domain=auto
```

**Ograniczenia SQLite:** Wolniejszy przy dużej ilości wtyczek/autorów. Nie wspiera wieloosobowej edycji równoczesnej.

## Wymagania

- **RAM:** ~150-200MB (limit kontenera: 256MB)
- **Dysk:** ~700MB (obraz Docker) + dane
- **MySQL:** Shared Mikrus (darmowy) lub własny. Tryb SQLite nie wymaga.

## Po instalacji

1. Otwórz stronę w przeglądarce - kreator instalacji WordPress
2. Ustaw język, tytuł strony, konto admina
3. Uruchom fix HTTPS + optymalizację wp-cron:
   ```bash
   ssh hanna 'cd /opt/stacks/wordpress && ./wp-init.sh'
   ```

## Optymalizacja wydajności

### Redis Object Cache (zalecany)

Jeśli masz Redis na serwerze (`./local/deploy.sh redis`):
1. Zainstaluj wtyczkę "Redis Object Cache" w panelu WP
2. Aktywuj - automatycznie wykryje Redis na localhost:6379
3. TTFB spadnie o 50-80%

### WP-Cron

Skrypt `wp-init.sh` wyłącza domyślny wp-cron (spowalnia każde odwiedziny) i sugeruje dodanie systemowego crona co 5 minut.

### Obraz wordpress:fpm-alpine

Dla maksymalnej wydajności zamień `wordpress:latest` na `wordpress:fpm-alpine` w docker-compose.yaml. Wymaga jednak konfiguracji FastCGI w reverse proxy.

## Backup

Cały WordPress jest w `/opt/stacks/wordpress/`:
- `wp-content/` - wtyczki, motywy, pliki, baza SQLite
- `docker-compose.yaml` - konfiguracja

```bash
./local/setup-backup.sh hanna
```
