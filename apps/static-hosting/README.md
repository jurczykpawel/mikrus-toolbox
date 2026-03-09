# Hosting Statyczny

Hostuj nieograniczoną liczbę stron statycznych na własnym serwerze. Bez opłat za stronę, bez limitów.

**RAM:** ~0MB extra (używa Caddy już działającego na serwerze) | **Dysk:** zależy od plików | **Plan:** Mikrus 1.0 (35 zł/rok, bez PRO)

## Szybki start

```bash
# Pliki już są na serwerze
./local/add-static-hosting.sh mojasites.example.com mikrus

# Wyślij lokalny katalog i opublikuj
./local/add-static-hosting.sh mojasites.example.com mikrus ./dist

# Wyślij do własnej ścieżki
./local/add-static-hosting.sh mojasites.example.com mikrus ./dist /var/www/mojasites
```

Skrypt robi wszystko automatycznie:
1. Tworzy katalog na serwerze
2. Wysyła pliki (jeśli podano `LOCAL_DIR`)
3. Instaluje Caddy jeśli go nie ma
4. Dodaje rekord DNS przez Cloudflare (jeśli skonfigurowane)
5. Konfiguruje Caddy `file_server` z auto-HTTPS

## Parametry

```
./local/add-static-hosting.sh DOMENA [SSH_ALIAS] [KATALOG_LOKALNY] [KATALOG_ZDALNY]
```

| Parametr | Domyślne | Opis |
|---|---|---|
| `DOMENA` | wymagane | Domena do obsługi (np. `blog.example.com`) |
| `SSH_ALIAS` | `mikrus` | Alias SSH z `~/.ssh/config` |
| `KATALOG_LOKALNY` | — | Lokalny katalog do wysłania (pomiń jeśli pliki już są na serwerze) |
| `KATALOG_ZDALNY` | `/var/www/DOMENA` | Zdalna ścieżka do serwowania plików |

## Wiele stron na jednym serwerze

Każda domena jest niezależna — dodawaj tyle stron ile masz miejsca na dysku:

```bash
./local/add-static-hosting.sh blog.example.com mikrus ./blog-dist
./local/add-static-hosting.sh docs.example.com mikrus ./docs-dist
./local/add-static-hosting.sh landing.example.com mikrus ./landing-dist
./local/add-static-hosting.sh cdn.example.com mikrus ./assets /var/www/cdn
```

Każda strona dostaje własny katalog pod `/var/www/` i własny blok w Caddy z auto-HTTPS. Żadnego dodatkowego RAM na stronę — Caddy obsługuje je wszystkie z jednego procesu.

## Aktualizacja plików

Uruchom tę samą komendę ponownie — rsync wysyła tylko zmienione pliki:

```bash
./local/add-static-hosting.sh mojasites.example.com mikrus ./dist
```

Albo ręczna synchronizacja:

```bash
./local/sync.sh up ./dist /var/www/mojasites.example.com --ssh=mikrus
```

## Porównanie kosztów

| Rozwiązanie | Cena/rok | Stron |
|---|---|---|
| Netlify Pro | ~1000 zł | nielimitowane (ale limit transferu) |
| Vercel Pro | ~1050 zł | nielimitowane (ale limit transferu) |
| GitHub Pages | 0 zł | 1 na repo (tylko publiczne) |
| Tiiny.host Pro | ~500 zł | 10 stron |
| Tiiny.host Business | ~1200 zł | 50 stron |
| **Hosting statyczny + Mikrus 1.0** | **35 zł/rok** | **bez limitów** |

**Tysiące stron statycznych za 35 zł rocznie.** Jedynym limitem jest miejsce na dysku (5GB na Mikrus 1.0).

## Przypadki użycia

- **Landing page** — strony jednoekranowe dla produktów, wydarzeń, kampanii
- **Dokumentacja** — eksport z Docusaurus, MkDocs, Astro itp.
- **Strony dla klientów** — dostarcz statyczne HTML/CSS, hostuj sam
- **Portfolio** — własne lub projektowe prezentacje
- **CDN dla zasobów** — obrazy, fonty, paczki JS serwowane z własnej domeny
- **Lead magnety** — PDFs, szablony, pliki do pobrania
- **Środowiska stagingowe** — podgląd zmian przed wdrożeniem

## Co jest wdrażane

Blok `file_server` w Caddy — najprostszy możliwy serwer WWW:

```
mojasites.example.com {
    root * /var/www/mojasites.example.com
    file_server
    encode gzip
}
```

- Auto-HTTPS przez Let's Encrypt (obsługiwane przez Caddy)
- Kompresja gzip
- Serwuje `index.html` dla żądań katalogów
- Żadnego PHP, bazy danych ani kontenera Docker

## Wymagania

- Caddy na serwerze (auto-instalowany przez skrypt jeśli go nie ma)
- DNS domeny wskazujący na IP serwera (lub Cloudflare skonfigurowane do auto-DNS)
- **Docker nie jest wymagany** — działa na gołym Mikrus 1.0 (35 zł/rok, bez PRO)

## Pojemność dysku na Mikrus 1.0

Mikrus 1.0 ma 5GB dysku. Strony statyczne są małe:

| Typ strony | Typowy rozmiar | Ile się zmieści |
|---|---|---|
| Landing page (HTML + CSS + zdjęcia) | ~1-5MB | 600-3000 |
| Strona dokumentacji | ~10-50MB | 60-300 |
| Portfolio ze zdjęciami | ~50-200MB | 15-60 |
| Blog (bez zdjęć) | ~1-10MB | 300-3000 |

Nawet przy WordPressie na tym samym serwerze zostaje ~1.4GB wolnego miejsca na strony statyczne.

## Troubleshooting

### Plik nie znaleziony / 404
Sprawdź czy pliki są w katalogu:
```bash
ssh mikrus "ls /var/www/mojasites.example.com/"
```

### Permission denied
```bash
ssh mikrus "sudo chmod -R o+rX /var/www/mojasites.example.com/"
```

### HTTPS nie działa
Caddy automatycznie wystawia certyfikaty Let's Encrypt. DNS musi wskazywać na serwer przed uruchomieniem skryptu. Sprawdź logi:
```bash
ssh mikrus "sudo journalctl -u caddy -n 50"
```
