# n8n Automation Platform

**Własny odpowiednik Make.com / Zapier bez limitów.**

## 📋 Wymagania

- **RAM:** Min. 600MB (zalecane 1GB)
- **Baza Danych:** Zewnętrzny PostgreSQL (Krytyczne dla Mikrusa 3.0!)

## 🚀 Instalacja

Uruchom z poziomu repozytorium:
```bash
./local/deploy.sh n8n
```

## 🗄️ Baza Danych (PostgreSQL)

Skrypt instalacyjny zapyta Cię o dane do bazy. **Nie instaluj Postgresa lokalnie na Mikrusie 3.0**, bo zabraknie Ci pamięci RAM na samo n8n.

### Opcja A: Mikrus Shared DB (Zalecane na start)
1. Zaloguj się do panelu [Mikrus.pl](https://panel.mikr.us).
2. Wejdź w zakładkę **Bazy Danych**.
3. Kliknij "Utwórz nową bazę PostgreSQL".
4. Otrzymasz dane: Host, Port, User, Hasło, Nazwa Bazy.
5. Podaj te dane podczas instalacji n8n.

### Opcja B: "Cegła" Bazy Danych (Dla Pro)
Jeśli chcesz mieć własną instancję bazy (nie współdzieloną), kup usługę "Baza Danych" (koszt ok. 29 zł/rok). Jest to znacznie wydajniejsze i bezpieczniejsze rozwiązanie niż współdzielony serwer.

## 📦 Backup

n8n przechowuje workflowy w bazie danych, a klucze szyfrowania (credentials) w pliku.
Aby zrobić pełny backup:

```bash
./local/deploy.sh apps/n8n/backup.sh
```

Stworzy to plik `.tar.gz` w `/opt/stacks/n8n/backups` na serwerze, który potem zostanie pobrany przez Twój główny system backupu (jeśli go skonfigurowałeś przez `setup-backup.sh`).

## 🔧 Power Tools
n8n w kontenerze nie ma dostępu do narzędzi systemowych. Aby używać `yt-dlp` lub `ffmpeg`, użyj węzła **"Execute Command"** z poleceniem SSH do localhost:

`ssh user@172.17.0.1 "yt-dlp ..."`