# 💰 GateFlow - Twój Własny System Sprzedaży Produktów Cyfrowych

**Open source alternatywa dla Gumroad, EasyCart, Teachable.**
Sprzedawaj e-booki, kursy, szablony i licencje bez miesięcznych opłat i prowizji platformy.

**RAM:** ~300MB | **Dysk:** ~500MB | **Plan:** Mikrus 3.0+ (1GB RAM)

---

## 🚀 Szybki Start

### Opcja 1: Dedykowane skrypty konfiguracyjne (zalecane)

```bash
# 1. Konfiguracja Supabase (+ migracje)
./local/setup-supabase-gateflow.sh hanna

# 2. Konfiguracja Stripe
./local/setup-stripe-gateflow.sh gf.twojadomena.pl

# 3. Deploy z zapisanymi konfiguracjami
source ~/.config/gateflow/supabase.env
source ~/.config/gateflow/stripe.env
STRIPE_PK="$STRIPE_PUBLISHABLE_KEY" STRIPE_SK="$STRIPE_SECRET_KEY" \
./local/deploy.sh gateflow --ssh=hanna --domain=gf.twojadomena.pl
```

### Opcja 2: Interaktywny deploy

```bash
# Interaktywny setup (zadaje pytania)
./local/deploy.sh gateflow --ssh=mikrus

# Z Cytrus (domena *.byst.re)
./local/deploy.sh gateflow --ssh=mikrus --domain-type=cytrus --domain=shop.byst.re

# Z Cloudflare (własna domena + Turnstile CAPTCHA)
./local/deploy.sh gateflow --ssh=mikrus --domain-type=cloudflare --domain=shop.mojafirma.pl
```

Skrypt przeprowadzi Cię przez:
1. **Supabase** - automatyczny setup (otwiera przeglądarkę) lub ręczne wpisanie kluczy
2. **Stripe** - skopiuj klucze z dashboardu
3. **Turnstile** - CAPTCHA dla Cloudflare (automatycznie dla --domain-type=cloudflare)
4. **Build & Start** - automatycznie

---

## 📋 Wymagania

| Usługa | Koszt | Do czego |
|--------|-------|----------|
| **Mikrus 3.0+** | ~16 zł/mies | Hosting aplikacji |
| **Supabase** | Darmowe | Baza danych w chmurze |
| **Stripe** | 2.9% + 1.20 zł/transakcja | Obsługa płatności |

### Przed instalacją przygotuj:

1. **Supabase** - https://supabase.com (załóż projekt)
2. **Stripe** - https://dashboard.stripe.com/apikeys (skopiuj klucze)

---

## 💸 Porównanie kosztów

| | EasyCart | Gumroad | **GateFlow** |
|---|---|---|---|
| Opłata miesięczna | 100 zł/mies | 10$/mies | **0 zł** |
| Prowizja od sprzedaży | 1-3% | 10% | **0%** |
| Własność danych | ❌ | ❌ | **✅** |
| Przy 300k zł/rok | ~16-19k zł | ~30k zł | **~8.7k zł** |

**Oszczędzasz 7,000-20,000 zł rocznie** hostując GateFlow na Mikrusie.

---

## ⚙️ Konfiguracja

### Supabase (dwie opcje)

**Opcja 1: Automatyczna (zalecana)**
```
Skrypt uruchomi 'bun run setup' który:
1. Poprosi o Personal Access Token z Supabase
2. Wylistuje Twoje projekty
3. Automatycznie pobierze klucze API
```

**Opcja 2: Ręczna**
```
1. Otwórz: https://supabase.com/dashboard
2. Wybierz projekt → Settings → API
3. Skopiuj: URL, anon key, service_role key
```

### Stripe

```
1. Otwórz: https://dashboard.stripe.com/apikeys
2. Skopiuj: Publishable key (pk_...) i Secret key (sk_...)
```

### Migracje bazy danych

Migracje wykonują się automatycznie przez Docker na serwerze:

```bash
# Przy pierwszej instalacji - razem z setup-supabase-gateflow.sh
./local/setup-supabase-gateflow.sh hanna

# Lub osobno
DATABASE_URL="postgresql://..." ./local/setup-supabase-migrations.sh hanna
```

Skrypt:
- Pobiera pliki migracji z GitHub
- Sprawdza które są już wykonane (tabela `schema_migrations`)
- Wykonuje brakujące przez Docker `postgres:15-alpine`

---

## ✨ Funkcje

### 🛒 Sprzedaż
- **Stripe Elements** - płatności bez przekierowań
- **26 walut** z automatyczną konwersją
- **Guest checkout** - zakupy bez rejestracji
- **Magic links** - logowanie bez hasła

### 📈 Lejki sprzedażowe
- **Order Bumps** - zwiększ wartość koszyka o 30-50%
- **One-Time Offers** - oferty po zakupie z licznikiem
- **Kupony** - procentowe, kwotowe, z limitami

### 🔐 Ochrona treści
- **JavaScript SDK** do ochrony dowolnej strony
- Działa z WordPress, Webflow, statycznymi stronami

### 🇪🇺 Zgodność z prawem
- **Omnibus Directive** - historia cen 30 dni
- **GDPR** - consent management
- **GUS REGON** - auto-uzupełnianie po NIP

---

## 🔗 Integracja z Mikrus Toolbox

```
[Klient] → [Typebot - chatbot] → [GateFlow - płatność]
                                        ↓
                               [Webhook do n8n]
                                        ↓
                    ┌───────────────────┼───────────────────┐
                    ↓                   ↓                   ↓
            [NocoDB - CRM]      [Listmonk - email]   [Fakturownia]
```

---

## 📁 Lokalizacja

**Na serwerze:**
```
~/gateflow/
├── admin-panel/
│   ├── .env.local      # Konfiguracja (Supabase, Stripe, URLs, Turnstile)
│   └── .next/standalone/  # Pre-built aplikacja
└── .env.local.backup   # Backup konfiguracji (tworzony przy update)
```

**Na lokalnej maszynie:**
```
~/.config/gateflow/
├── supabase.env    # Klucze Supabase (setup-supabase-gateflow.sh)
└── stripe.env      # Klucze Stripe (setup-stripe-gateflow.sh)

~/.config/cloudflare/
└── turnstile_keys_DOMENA  # Klucze Turnstile (setup-turnstile.sh)
```

---

## 🔧 Zarządzanie

```bash
# Status
pm2 status

# Logi
pm2 logs gateflow-admin

# Restart
pm2 restart gateflow-admin
```

### Aktualizacja

```bash
# Z lokalnej maszyny (przez SSH)
ssh hanna 'bash -s' < apps/gateflow/update.sh

# Lub bezpośrednio na serwerze
./apps/gateflow/update.sh
```

Skrypt update.sh:
1. Pobiera najnowszą wersję z GitHub Releases
2. Zachowuje konfigurację (.env.local)
3. Pyta o DATABASE_URL i wykonuje migracje (opcjonalnie)
4. Restartuje aplikację

---

## 🔒 Turnstile (CAPTCHA)

Dla domen Cloudflare automatycznie konfigurowany jest Turnstile (CAPTCHA bez CAPTCHA):

```bash
# Automatycznie przy deploy z --domain-type=cloudflare
./local/deploy.sh gateflow --ssh=hanna --domain-type=cloudflare --domain=gf.example.com

# Lub osobno (jeśli już masz GateFlow)
./local/setup-turnstile.sh gf.example.com hanna
```

Klucze są automatycznie dodawane do `.env.local` i aplikacja restartowana.

---

## 🔒 Stripe Webhooks

Po instalacji skonfiguruj webhooks:

1. Otwórz: https://dashboard.stripe.com/webhooks
2. Add endpoint: `https://twoja-domena.pl/api/webhooks/stripe`
3. Events:
   - `checkout.session.completed`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Skopiuj Signing Secret (`whsec_...`)
5. Dodaj do `~/gateflow/admin-panel/.env.local`:
   ```
   STRIPE_WEBHOOK_SECRET=whsec_...
   ```
6. Restart: `pm2 restart gateflow-admin`

---

## ❓ FAQ

**Q: Czy to naprawdę darmowe?**
A: Tak! GateFlow jest open source (MIT). Płacisz tylko za hosting (~16 zł/mies) i Stripe (2.9% + 1.20 zł).

**Q: Dlaczego Supabase a nie lokalna baza?**
A: Supabase daje darmowy hosting PostgreSQL + Auth + Realtime. Mniej rzeczy do utrzymania na Mikrusie.

**Q: Czy pierwszy user to admin?**
A: Tak! Pierwsza osoba która się zarejestruje automatycznie dostaje uprawnienia admina.

**Q: Testowa karta do Stripe?**
A: `4242 4242 4242 4242` (dowolna data, dowolne CVC)

---

> 📖 **Więcej:** https://github.com/pavvel11/gateflow
