# 🤖 n8n - Twój silnik automatyzacji

**Alternatywa dla Make.com / Zapier bez limitów operacji.**
Łącz aplikacje, automatyzuj procesy, buduj workflowy wizualnie.

> 🔗 **Oficjalna strona:** https://n8n.io

---

## 💸 Dlaczego n8n?

| | Zapier | Make | **n8n** |
|---|---|---|---|
| 100 tasków/mies | 0 zł | 0 zł | **0 zł** |
| 2000 tasków/mies | ~100 zł/mies | ~50 zł/mies | **0 zł** |
| Bez limitów | ~400 zł/mies | ~150 zł/mies | **0 zł** |

Płacisz tylko za hosting (~16 zł/mies).

---

## 📋 Wymagania

- **RAM:** Min. 600MB (zalecane 1GB na Mikrus 3.0)
- **PostgreSQL:** Obowiązkowy (zewnętrzna baza!)

> ⚠️ **WAŻNE:** Nie instaluj PostgreSQL lokalnie na Mikrusie 3.0 - zabraknie RAM-u na samo n8n!

### PostgreSQL - opcje na Mikrusie

> ⚠️ **Współdzielona baza Mikrusa NIE działa!** n8n wymaga rozszerzenia `pgcrypto` (`gen_random_uuid()`), które nie jest dostępne na shared PostgreSQL 12. Potrzebujesz dedykowanej bazy.

#### Dedykowana baza PostgreSQL (wymagana)

| RAM | Dysk | Połączenia | Cena/rok |
|---|---|---|---|
| 512 MB | 10 GB | 100 | **29 zł** |
| 1024 MB | 50 GB | 100 | 119 zł |

👉 [Kup bazę w Panel Mikrus → Cloud](https://mikr.us/panel/?a=cloud)

> 💡 **Rekomendacja:** Baza 10GB za 29 zł/rok to inwestycja na lata. Wystarczy na n8n + Listmonk + Umami.

---

## 🚀 Instalacja

### Krok 1: Przygotuj dane do bazy

Z panelu Mikrusa potrzebujesz:
- **Host** - np. `srv34.mikr.us` lub adres z chmury
- **Database** - nazwa bazy
- **User** - nazwa użytkownika
- **Password** - hasło

### Krok 2: Uruchom instalator

```bash
./local/deploy.sh n8n
```

Skrypt zapyta o:
- Dane bazy PostgreSQL
- Domenę (np. `n8n.mojafirma.pl`)

### Krok 3: Skonfiguruj domenę

**Caddy:**
```bash
mikrus-expose n8n.mojafirma.pl 5678
```

**Cytrus:** Panel Mikrus → Domeny → przekieruj na port 5678

---

## 📦 Backup

n8n przechowuje workflowy w bazie danych, a klucze szyfrowania (credentials) w pliku.

Pełny backup:
```bash
./local/deploy.sh apps/n8n/backup.sh
```

Tworzy `.tar.gz` w `/opt/stacks/n8n/backups` na serwerze.

---

## 🔧 Power Tools

n8n w kontenerze nie ma dostępu do narzędzi systemowych (yt-dlp, ffmpeg).

Aby ich użyć, w węźle **"Execute Command"** wpisz:
```bash
ssh user@172.17.0.1 "yt-dlp https://youtube.com/..."
```

To łączy się z kontenera do hosta, gdzie są zainstalowane narzędzia.

---

## 🔗 Integracja z ekosystemem

n8n to "mózg" Twojej automatyzacji:

```
[Sellf - sprzedaż] ──webhook──→ [n8n]
[Typebot - chatbot]  ──webhook──→   │
[Uptime Kuma - alert] ─webhook──→   │
                                    ↓
              ┌─────────────────────┼─────────────────────┐
              ↓                     ↓                     ↓
      [NocoDB - CRM]        [Listmonk - mail]    [ntfy - push]
```

---

## ❓ FAQ

**Q: Ile RAM-u zużywa n8n?**
A: 400-600MB w spoczynku, więcej przy skomplikowanych workflow.

**Q: Mogę używać SQLite zamiast PostgreSQL?**
A: Możesz, ale nie zalecamy. SQLite blokuje się przy wielu równoczesnych operacjach.

**Q: Jak przenieść workflow z Make/Zapier?**
A: Ręcznie - n8n ma inne konektory. Ale większość popularnych integracji (Slack, Google Sheets, Stripe) działa podobnie.
