# 🔗 LittleLink - Wizytówka (Wersja Lekka)

Ekstremalnie lekka alternatywa dla Linktree. Czysty HTML + CSS.

## 🚀 Instalacja

```bash
./local/deploy.sh littlelink
```

## 🛠️ Jak edytować?
LittleLink nie ma panelu admina. Edytujesz plik `index.html`.

**Workflow "Lazy Engineera":**
1. Użyj `./local/sync.sh down /var/www/twoja-domena ./moj-bio`, aby pobrać pliki na Maca.
2. Wyedytuj `index.html` w VS Code (dodaj swoje linki).
3. Użyj `./local/sync.sh up ./moj-bio /var/www/twoja-domena`, aby wysłać zmiany na serwer.

Zero bazy danych. Zero PHP. Działa błyskawicznie nawet na najtańszym Mikrusie.