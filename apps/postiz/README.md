# Postiz - Planowanie Postów w Social Media

Alternatywa dla Buffer/Hootsuite. Planuj posty na Twitter/X, LinkedIn, Instagram, Facebook, TikTok i więcej.

## Dlaczego Postiz?

| Cecha | Postiz | Buffer | Hootsuite |
|-------|--------|--------|-----------|
| Cena | Darmowy (self-hosted) | Od $6/mies. | Od $99/mies. |
| Platformy | 10+ | 8 | 10+ |
| AI content | Wbudowane | Płatne | Płatne |
| Limity postów | Brak | 2000/mies. | Zależne od planu |

## Instalacja

```bash
./local/deploy.sh postiz --ssh=hanna --domain-type=cytrus --domain=auto
```

Deploy.sh automatycznie skonfiguruje bazę PostgreSQL (shared Mikrus lub własna).

## Wymagania

- **RAM:** zalecane 2GB (Mikrus 2.0+), da się uruchomić na 1GB
- **Dysk:** ~1.2GB (obraz Docker)
- **Baza danych:** PostgreSQL (shared Mikrus lub własna)
- **Redis:** Bundled w docker-compose (nie wymaga osobnej instalacji)

## Po instalacji

1. Otwórz stronę w przeglądarce
2. Utwórz konto administratora
3. Podłącz konta social media
4. Zaplanuj pierwsze posty!

## Obsługiwane platformy

- Twitter/X
- LinkedIn
- Instagram
- Facebook
- TikTok
- YouTube
- Pinterest
- Reddit
- i więcej...

## Backup

```bash
./local/setup-backup.sh hanna
```

Dane w `/opt/stacks/postiz/`:
- `uploads/` - przesłane pliki
- `redis-data/` - cache Redis
- Baza PostgreSQL - backup przez Mikrus panel lub pg_dump
