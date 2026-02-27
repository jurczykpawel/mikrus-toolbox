# 📧 Listmonk - Twój system newsletterowy

**Alternatywa dla Mailchimp / MailerLite / ActiveCampaign.**
Wysyłaj maile do tysięcy subskrybentów bez miesięcznych opłat za bazę.

> 🔗 **Oficjalna strona:** https://listmonk.app

---

## 💸 Dlaczego Listmonk?

| | Mailchimp | MailerLite | **Listmonk** |
|---|---|---|---|
| 1000 subskrybentów | 0 zł | 0 zł | **0 zł** |
| 10 000 subskrybentów | ~200 zł/mies | ~100 zł/mies | **0 zł** |
| 50 000 subskrybentów | ~800 zł/mies | ~300 zł/mies | **0 zł** |

Płacisz tylko za hosting (~16 zł/mies) i wysyłkę maili przez SMTP (np. Amazon SES: ~$1 za 10 000 maili).

---

## 📋 Wymagania

### PostgreSQL (obowiązkowe)

Listmonk wymaga bazy PostgreSQL z rozszerzeniem **pgcrypto** (od v6.0.0).

> ⚠️ **Współdzielona baza Mikrusa NIE działa!** Brak uprawnień do tworzenia rozszerzeń. Potrzebujesz dedykowanej bazy.

#### Dedykowana baza PostgreSQL

Zamów w [Panel Mikrus → Cloud](https://mikr.us/panel/?a=cloud):

| RAM | Dysk | Połączenia | Cena/rok |
|---|---|---|---|
| 512 MB | 10 GB | 100 | **29 zł** |
| 1024 MB | 50 GB | 100 | 119 zł |

👉 [Kup bazę w Panel Mikrus → Cloud](https://mikr.us/panel/?a=cloud)

> 💡 **Rekomendacja:** Baza 10GB za 29 zł/rok wystarczy na lata. Koszt minimalny, a masz pewność że dane są bezpieczne i nie dzielisz zasobów z innymi.

---

## 🚀 Instalacja

### Krok 1: Przygotuj dane do bazy

Z panelu Mikrusa (opcja A lub B powyżej) potrzebujesz:
- **Host** - np. `srv34.mikr.us` lub adres z chmury
- **Database** - nazwa bazy
- **User** - nazwa użytkownika
- **Password** - hasło

### Krok 2: Uruchom instalator

```bash
./local/deploy.sh listmonk
```

Skrypt zapyta o:
- Dane bazy PostgreSQL (host, database, user, password)
- Domenę (np. `newsletter.mojafirma.pl`)

### Krok 3: Skonfiguruj domenę

Po instalacji wystaw aplikację przez HTTPS:

**Caddy:**
```bash
mikrus-expose newsletter.mojafirma.pl 9000
```

**Cytrus:** Panel Mikrus → Domeny → przekieruj na port 9000

### Krok 4: Zaloguj się i skonfiguruj SMTP

1. Wejdź na `https://newsletter.mojafirma.pl`
2. Zaloguj się: **admin** / **listmonk**
3. **Zmień hasło!**
4. Skonfiguruj serwer mailowy — [szczegóły](#-konfiguracja-smtp)

### Krok 5: Zabezpiecz formularze

1. Settings → Security → Captcha → **ALTCHA: ON** (proof-of-work, blokuje boty)
2. Subscribers → Lists → każda publiczna lista → Opt-in: **Double** (potwierdza email)
3. Settings → Security → CORS Origins → domena landing page'a (jeśli formularz jest na innej domenie niż Listmonk)

### Krok 6: Skonfiguruj domeny wysyłkowe

DNS (SPF, DKIM, DMARC) + bounce handling + powiadomienia — [szczegóły](#%EF%B8%8F-konfiguracja-domeny-wysylkowej-dkim-dmarc-bounce)

---

## 📬 Konfiguracja SMTP

Listmonk sam nie wysyła maili - potrzebujesz serwera SMTP:

| Usługa | Koszt | Limit |
|---|---|---|
| **Amazon SES** | ~$1 / 10 000 maili | Praktycznie bez limitu |
| **Mailgun** | $0 (3 mies.) potem $35/mies | 5000/mies free |
| **Resend** | $0 | 3000/mies free |
| **Własny serwer** | 0 zł | Ryzyko blacklisty |

> 💡 **Rekomendacja:** Amazon SES - najtańszy przy skali, wymaga weryfikacji domeny.

---

## 🛡️ Konfiguracja domeny wysyłkowej (DKIM, DMARC, bounce)

Po skonfigurowaniu SMTP uruchom skrypt konfiguracji:

```bash
# Pełny setup: DNS + Listmonk API + restart
./local/setup-listmonk-mail.sh mojafirma.pl sklep.mojafirma.pl \
    --listmonk-url=https://newsletter.mojafirma.pl --ssh=mikrus

# Tylko DNS (bez konfiguracji Listmonka) — działa z dowolnym mailerem
./local/setup-mail-domain.sh mojafirma.pl sklep.mojafirma.pl
```

**`setup-mail-domain.sh`** — uniwersalny skrypt DNS (działa z każdym mailerem):

| Element | Co robi | Dlaczego ważne |
|---|---|---|
| **SPF** | Audyt istniejących rekordów | Bez SPF maile są odrzucane |
| **DKIM** | Dodaje rekordy z SES/EmailLabs/innego do Cloudflare | Bez DKIM maile lądują w spamie |
| **DMARC** | Dodaje politykę + cross-domain auth records | Chroni przed spoofingiem |
| **Bounce guide** | Instrukcje SNS (jeśli podano --webhook-url) | Bez tego SES zawiesi konto |

**`setup-listmonk-mail.sh`** — wrapper: wywołuje powyższy + dodaje:

| Element | Co robi |
|---|---|
| **Bounce handling** | PUT /api/settings — SES webhook ON, count=1, action=blocklist |
| **Powiadomienia** | PUT /api/settings — notification emails |
| **Restart** | docker compose restart via --ssh=ALIAS |

Wymaga wcześniejszej konfiguracji Cloudflare (`./local/setup-cloudflare.sh`) do automatycznego dodawania rekordów DNS.

### Ręczna konfiguracja

Jeśli nie chcesz używać skryptu, dodaj ręcznie w Cloudflare DNS:

**DKIM (dla każdej domeny, z panelu SES/EmailLabs):**
- 3 rekordy CNAME z konsoli SES (Authentication → DKIM)
- 1 rekord CNAME/TXT z panelu EmailLabs

**DMARC (dla każdej domeny):**
```
_dmarc.twojadomena.pl  TXT  "v=DMARC1; p=none; rua=mailto:dmarc-reports@twojadomena.pl"
```

**Bounce handling:**
1. AWS SNS → topic `listmonk-bounces` → subscription HTTPS → `https://TWOJ-LISTMONK/webhooks/service/ses`
2. AWS SES → każda domena → Notifications → Bounce + Complaint → topic `listmonk-bounces`
3. Listmonk → Settings → Bounces → Enable SES, count=1, action=blocklist

---

## 🔗 Integracja z n8n

Po zakupie w Sellf lub rozmowie w Typebocie możesz automatycznie dodawać osoby do Listmonka.

**Przykład workflow n8n:**
```
[Webhook z Sellf] → [HTTP Request do Listmonk API] → [Dodaj do listy "Klienci"]
```

Listmonk API: `https://listmonk.app/docs/apis/subscribers/`

---

## ❓ FAQ

**Q: Ile RAM-u zużywa Listmonk?**
A: ~50-100MB. Napisany w Go, bardzo lekki.

**Q: Mogę importować subskrybentów z Mailchimp?**
A: Tak! Eksportuj CSV z Mailchimp i zaimportuj w Listmonk → Subscribers → Import.

**Q: Jak uniknąć spamu?**
A: Skonfiguruj SPF, DKIM i DMARC dla swojej domeny. Listmonk ma wbudowaną obsługę double opt-in.
