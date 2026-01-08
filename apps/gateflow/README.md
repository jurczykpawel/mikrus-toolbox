# 💰 GateFlow - Twój Własny System Sprzedaży Produktów Cyfrowych

**Open source alternatywa dla Gumroad, EasyCart, Teachable.**
Sprzedawaj e-booki, kursy, szablony i licencje bez miesięcznych opłat i prowizji platformy.

> 🔗 **GitHub:** https://github.com/pavvel11/gateflow
> 📖 **Pełna lista funkcji:** [FEATURES.md](https://github.com/pavvel11/gateflow/blob/main/FEATURES.md)

---

## 💸 Dlaczego GateFlow zamiast SaaS?

| | EasyCart | Gumroad | **GateFlow** |
|---|---|---|---|
| Opłata miesięczna | 100 zł/mies | 10$/mies | **0 zł** |
| Prowizja od sprzedaży | 1-3% | 10% | **0%** |
| Własność danych | ❌ | ❌ | **✅** |
| Przy 300k zł/rok przychodu | ~16-19k zł | ~30k zł | **~8.7k zł** (tylko Stripe) |

**Oszczędzasz 7,000-20,000 zł rocznie** hostując GateFlow na Mikrusie za ~16 zł/mies.

---

## 🚀 Instalacja

```bash
./local/deploy.sh gateflow
```

GateFlow działa natywnie przez **PM2** (nie Docker) dla maksymalnej lekkości (~300MB RAM).

**Wymagania:**
- Mikrus 3.0+ (1GB RAM) lub wyższy
- Konto Supabase (darmowe) - baza danych w chmurze
- Konto Stripe (darmowe) - obsługa płatności

---

## ✨ Kluczowe Funkcje

### 🛒 Sprzedaż i Checkout
- **Stripe Elements** - płatności bez przekierowań (PCI DSS compliant)
- **26 walut** z automatyczną konwersją kursów
- **Guest checkout** - zakupy bez rejestracji
- **Magic links** - logowanie bez hasła
- **Pay What You Want (PWYW)** - "zapłać ile chcesz"

### 📈 Lejki Sprzedażowe
- **Order Bumps** - zwiększ wartość koszyka o 30-50%
- **One-Time Offers (OTO)** - oferty po zakupie z licznikiem czasu
- **Kupony** - procentowe, kwotowe, z limitami, auto-apply
- **Waitlist** - zbieraj emaile przed premierą produktu

### 🔐 Ochrona Treści (Gatekeeper)
- **JavaScript SDK** do ochrony dowolnej strony
- Działa z WordPress, Webflow, statycznymi stronami
- Ochrona całej strony lub pojedynczych elementów
- Custom fallback dla osób bez dostępu

### 📊 Marketing i Analityka
- **Dashboard na żywo** - przychody, zamówienia, cele
- **Google Tag Manager** - pełna integracja
- **Facebook Pixel + CAPI** - server-side tracking
- **Webhooks HMAC** - bezpieczna integracja z n8n/Make/Zapier

### 🇪🇺 Zgodność z Prawem (EU)
- **Omnibus Directive** - automatyczna historia cen 30 dni
- **GDPR** - logowanie zgód, consent management
- **GUS REGON** - auto-uzupełnianie danych firmy po NIP (B2B)

### 🎨 White-label
- Własne logo, kolory, czcionki
- Pełna personalizacja storefront
- Twoja domena, Twój branding

---

## 🔗 Integracja z Ekosystemem Mikrus

GateFlow świetnie współpracuje z innymi narzędziami z Toolboxa:

```
[Klient] → [Typebot - chatbot] → [GateFlow - płatność]
                                        ↓
                               [Webhook do n8n]
                                        ↓
                    ┌───────────────────┼───────────────────┐
                    ↓                   ↓                   ↓
            [NocoDB - CRM]      [Listmonk - email]   [Fakturownia - faktura]
```

### Przykładowy Webhook do n8n

Po każdym zakupie GateFlow wysyła webhook `purchase.completed`:

```json
{
  "event": "purchase.completed",
  "data": {
    "email": "klient@example.com",
    "product_name": "Kurs SEO",
    "amount": 297,
    "currency": "PLN"
  }
}
```

W n8n możesz:
- Dodać klienta do NocoDB (CRM)
- Wysłać email powitalny przez Listmonk
- Wystawić fakturę przez API Fakturowni
- Wysłać powiadomienie na telefon przez ntfy

---

## 📦 Co Możesz Sprzedawać?

| Typ produktu | Przykłady |
|---|---|
| **E-booki & PDF** | Poradniki, raporty, checklisty |
| **Kursy online** | Wideo z kontrolą dostępu czasowego |
| **Szablony** | Notion, Figma, Excel, kod |
| **Licencje software** | Klucze API, dostęp do SaaS |
| **Lead magnety** | Darmowe produkty do budowania listy |
| **Członkostwa** | Dostęp czasowy (30/90 dni/lifetime) |

---

## 🛡️ Bezpieczeństwo

- **AES-256-GCM** - szyfrowanie kluczy API
- **Row Level Security (RLS)** - izolacja danych w Supabase
- **Rate limiting** - ochrona przed atakami
- **HMAC webhooks** - weryfikacja pochodzenia requestów
- **Audit logging** - pełna historia zmian
- **Cloudflare Turnstile** - ochrona przed botami

---

## 📈 Statystyki Projektu

```
├── 571 testów E2E (100% pass rate)
├── 54+ endpointów API
├── 25+ tabel w bazie
├── 40+ funkcji RPC
├── 50+ polityk RLS
└── 2 języki (PL, EN)
```

---

## 🔧 Zarządzanie

```bash
# Logi
ssh mikrus "pm2 logs gateflow"

# Restart
ssh mikrus "pm2 restart gateflow"

# Status
ssh mikrus "pm2 status"
```

---

## 📚 Dokumentacja

- [DEPLOYMENT.md](https://github.com/pavvel11/gateflow/blob/main/DEPLOYMENT.md) - Pełny przewodnik wdrożenia
- [FEATURES.md](https://github.com/pavvel11/gateflow/blob/main/FEATURES.md) - Lista wszystkich funkcji
- [STRIPE-TESTING-GUIDE.md](https://github.com/pavvel11/gateflow/blob/main/STRIPE-TESTING-GUIDE.md) - Testowanie płatności

---

## ❓ FAQ

**Q: Czy to naprawdę darmowe?**
A: Tak! GateFlow jest open source (MIT). Płacisz tylko za hosting (~16 zł/mies na Mikrusie) i standardowe opłaty Stripe (2.9% + 1.20 zł).

**Q: Czy muszę być programistą?**
A: Podstawowa znajomość terminala wystarczy. Skrypt instalacyjny przeprowadzi Cię przez proces krok po kroku.

**Q: Czy mogę usunąć branding GateFlow?**
A: Tak, licencja MIT pozwala na pełną personalizację - logo, kolory, domena, nawet kod źródłowy.

**Q: Co z subskrypcjami?**
A: Stripe Subscriptions są w roadmapie. Obecnie obsługiwane są jednorazowe płatności i dostęp czasowy.
