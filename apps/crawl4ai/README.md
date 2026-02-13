# Crawl4AI - AI Web Crawler i Scraper

REST API do crawlowania stron z headless Chromium. Ekstrakcja danych przez AI, output w Markdown/JSON.

## Dlaczego Crawl4AI?

| Cecha | Crawl4AI | Apify | ScrapingBee |
|-------|----------|-------|-------------|
| Cena | Darmowy (self-hosted) | Od $49/mies. | Od $49/mies. |
| AI extraction | Wbudowane (LLM) | Tak (płatne) | Nie |
| JavaScript | Headless Chromium | Tak | Tak |
| Limity | Brak | Zależne od planu | Zależne od planu |

## Instalacja

```bash
./local/deploy.sh crawl4ai --ssh=hanna --domain-type=cytrus --domain=auto
```

## Wymagania

- **RAM:** minimum 2GB (Mikrus 2.0+)
- **Dysk:** ~2.5GB (obraz Docker z Chromium)
- **Baza danych:** Nie wymaga

**Crawl4AI NIE zadziała na Mikrus 1.0 (1GB RAM)!** Headless Chromium potrzebuje ~1-1.5GB RAM.

## Użycie

### REST API

```bash
# Crawluj stronę
curl -X POST https://twoja-domena/crawl \
  -H "Authorization: Bearer $(cat /opt/stacks/crawl4ai/.api_token)" \
  -H "Content-Type: application/json" \
  -d '{"urls": ["https://example.com"]}'
```

### Z n8n

Crawl4AI świetnie się integruje z n8n do automatycznego scrapingu:
1. HTTP Request node → POST do Crawl4AI API
2. Parsuj odpowiedź (Markdown/JSON)
3. Zapisz dane lub wyślij powiadomienie

## API Token

Token jest generowany automatycznie podczas instalacji i zapisany w:
```
/opt/stacks/crawl4ai/.api_token
```

## Backup

Crawl4AI jest bezstanowy - nie przechowuje danych. Wystarczy backup docker-compose.yaml i .api_token.
