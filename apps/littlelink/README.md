# LittleLink - Wizytowka (Wersja Lekka)

Ekstremalnie lekka alternatywa dla Linktree. Czysty HTML + CSS, zero bazy danych, zero PHP.

## Instalacja

```bash
./local/deploy.sh littlelink --ssh=mikrus --domain-type=cytrus --domain=auto
```

## Wymagania

- **RAM:** ~5MB (nginx:alpine)
- **Dysk:** ~50MB (obraz Docker)
- **Baza danych:** brak
- **Port:** 8090

## Jak edytowac?

LittleLink nie ma panelu admina. Edytujesz plik `index.html` bezposrednio.

**Workflow:**
1. Pobierz pliki na komputer:
   ```bash
   ./local/sync.sh down mikrus /opt/stacks/littlelink/html ./moj-bio
   ```
2. Wyedytuj `index.html` w VS Code (dodaj swoje linki, avatar, kolory)
3. Wyslij zmiany na serwer:
   ```bash
   ./local/sync.sh up mikrus ./moj-bio /opt/stacks/littlelink/html
   ```

Dziala blyskawicznie nawet na najtanszym Mikrusie.
