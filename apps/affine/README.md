# 📝 AFFiNE - Twój prywatny Notion + Miro

Open-source baza wiedzy, która łączy dokumenty, tablice (whiteboardy) i bazy danych w jednym narzędziu. Pełna alternatywa dla Notion i Miro — z danymi na Twoim serwerze, bez abonamentu i bez limitów.

## 🚀 Instalacja

```bash
# Domyślnie — bundluje PostgreSQL 16 (pgvector) + Redis (zero konfiguracji)
./local/deploy.sh affine --ssh=<alias> --domain-type=cytrus --domain=auto

# Z własną bazą danych (PostgreSQL 16+ z pgvector!)
./local/deploy.sh affine --ssh=<alias> --db=custom --domain-type=cytrus --domain=auto
```

**Wymagania:**
- PostgreSQL 16 z rozszerzeniem **pgvector** (bundlowany automatycznie)
- Redis (bundlowany automatycznie)
- Minimum **2GB RAM** (zalecane 4GB — Mikrus 3.5+)
- Dysk: ~750MB na obrazy Docker

> ⚠️ **Współdzielona baza Mikrusa NIE działa!** To PostgreSQL 12 bez rozszerzenia pgvector. AFFiNE wymaga PostgreSQL 16+ z pgvector. Użyj bundlowanej bazy (domyślnie) lub dedykowanego PostgreSQL.

## 💡 Dlaczego warto?

- **Wszystko w jednym:** dokumenty, tablice, bazy danych i kanban — bez przełączania między Notion, Miro i Airtable.
- **Prywatność:** dane na Twoim serwerze, nie w chmurze amerykańskiej korporacji.
- **Offline-first:** edytuj dokumenty bez internetu, synchronizuj gdy wrócisz online.
- **Open-source:** zero opłat, zero limitów, pełna kontrola nad danymi.

## Stack (4 kontenery)

| Kontener | Obraz | RAM | Rola |
|----------|-------|-----|------|
| affine | ghcr.io/toeverything/affine:stable | ~1024MB | Aplikacja (serwer) |
| affine_migration | ghcr.io/toeverything/affine:stable | jednorazowo | Migracja bazy danych |
| postgres | pgvector/pgvector:pg16 | ~256MB | Baza danych z pgvector |
| redis | redis:alpine | ~128MB | Cache |

**Port:** 3010 (konfigurowalny)

**Zużycie RAM:** ~1.5GB łącznie (app + postgres + redis)

## Po instalacji

1. Otwórz stronę w przeglądarce
2. Utwórz konto administratora — pierwszy zarejestrowany użytkownik staje się adminem

## Backup

```bash
./local/setup-backup.sh <alias>
```

Dane w `/opt/stacks/affine/`:
- `storage/` — pliki i załączniki
- `config/` — konfiguracja AFFiNE
- `db-data` — volume z bazą PostgreSQL (pgvector)
