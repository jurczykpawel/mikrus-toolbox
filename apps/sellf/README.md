# Sellf - Twój Własny System Sprzedaży Produktów Cyfrowych

**Open source alternatywa dla Gumroad, EasyCart, Teachable.**
Sprzedawaj e-booki, kursy, szablony i licencje bez miesięcznych opłat i prowizji platformy.

**RAM:** ~130MB | **Dysk:** ~500MB | **Plan:** Mikrus 1.0+ (35 zł/rok)

> **Uwaga:** W przykładach używamy `--ssh=mikrus` jako domyślnego aliasu SSH.
> Jeśli masz inny alias w `~/.ssh/config`, zamień `mikrus` na swój (np. `srv1`, `mojserwer`).

---

## Dwa tryby instalacji

Sellf obsługuje **dwa tryby** instalacji:

| Tryb | Dla kogo | Opis |
|------|----------|------|
| **Interaktywny** | Pierwsza instalacja | Skrypt zadaje pytania krok po kroku |
| **Automatyczny** | CI/CD, MCP, powtarzalne deploye | Wszystkie klucze z CLI lub zapisanej konfiguracji |

---

## Szybki Start

### Tryb interaktywny (najprostszy)

```bash
./local/deploy.sh sellf --ssh=mikrus
```

Skrypt przeprowadzi Cię przez:
1. Logowanie do Supabase (otworzy przeglądarkę)
2. Wybór projektu Supabase
3. Klucze Stripe (opcjonalne - możesz później)
4. Konfigurację domeny
5. Turnstile CAPTCHA (opcjonalne)

### Tryb automatyczny (dla zaawansowanych)

```bash
# KROK 1: Jednorazowa konfiguracja (zbiera i zapisuje wszystkie klucze)
./local/setup-sellf-config.sh

# KROK 2: Deployment (w pełni automatyczny, bez pytań)
./local/deploy.sh sellf --ssh=mikrus --yes
```

---

## Wymagania

| Usługa | Koszt | Do czego | Obowiązkowe |
|--------|-------|----------|-------------|
| **Mikrus 1.0+** | 35 zł/rok | Hosting aplikacji | Tak |
| **Supabase** | Darmowe | Baza danych + Auth | Tak |
| **Stripe** | 2.9% + 1.20 zł/transakcja | Płatności | Nie* |
| **Cloudflare** | Darmowe | Turnstile CAPTCHA | Nie |

*Stripe możesz skonfigurować później w panelu Sellf.

### Przed instalacją załóż konta:

1. **Supabase** - https://supabase.com (utwórz projekt)
2. **Stripe** - https://dashboard.stripe.com/apikeys (opcjonalne)
3. **Cloudflare** - https://dash.cloudflare.com (opcjonalne, dla Turnstile)

---

## Tryb Interaktywny (szczegóły)

### Podstawowa komenda

```bash
./local/deploy.sh sellf --ssh=ALIAS
```

### Parametry opcjonalne

```bash
# Z domeną Cytrus (automatyczna subdomena *.byst.re)
./local/deploy.sh sellf --ssh=mikrus --domain=auto --domain-type=cytrus

# Z własną domeną (Cloudflare DNS)
./local/deploy.sh sellf --ssh=mikrus --domain=shop.example.com --domain-type=cloudflare

# Z konkretnym projektem Supabase (pomija wybór z listy)
./local/deploy.sh sellf --ssh=mikrus --supabase-project=abcdefghijk
```

### Co się dzieje podczas instalacji

```
1. Logowanie do Supabase
   ├─ Automatyczne (otwiera przeglądarkę) lub
   └─ Ręczne (wklejasz Personal Access Token)

2. Wybór projektu Supabase
   └─ Lista Twoich projektów → wybierasz numer

3. Konfiguracja Stripe (opcjonalne)
   ├─ Podajesz klucze pk_... i sk_... lub
   └─ Pomijasz → skonfigurujesz w panelu później

4. Wybór domeny
   ├─ Automatyczna Cytrus (np. xyz123.byst.re)
   ├─ Własna subdomena Cytrus
   └─ Własna domena Cloudflare

5. Turnstile CAPTCHA (opcjonalne)
   └─ Automatycznie przez API lub ręcznie

6. Instalacja i uruchomienie
   └─ Build → Start → Migracje bazy
```

---

## Tryb Automatyczny (szczegóły)

Tryb automatyczny wymaga **wcześniejszego zebrania kluczy** za pomocą skryptu konfiguracyjnego.

### Krok 1: Zbieranie kluczy

```bash
./local/setup-sellf-config.sh
```

Skrypt zbiera i zapisuje do `~/.config/sellf/deploy-config.env`:
- Token Supabase + klucze projektu
- Klucze Stripe (opcjonalne)
- Klucze Turnstile (opcjonalne)
- SSH alias
- Domenę

### Krok 2: Automatyczny deployment

```bash
./local/deploy.sh sellf --ssh=mikrus --yes
```

Flaga `--yes` oznacza:
- Brak pytań interaktywnych
- Użycie zapisanej konfiguracji
- Automatyczna konfiguracja Turnstile (jeśli masz token Cloudflare)

### Parametry setup-sellf-config.sh

| Parametr | Opis | Przykład |
|----------|------|----------|
| `--ssh=ALIAS` | SSH alias serwera | `--ssh=mikrus` |
| `--domain=DOMAIN` | Domena lub `auto` | `--domain=auto` |
| `--domain-type=TYPE` | `cytrus` lub `cloudflare` | `--domain-type=cytrus` |
| `--supabase-project=REF` | Project ref (pomija wybór) | `--supabase-project=abc123` |
| `--no-supabase` | Bez konfiguracji Supabase | |
| `--no-stripe` | Bez konfiguracji Stripe | |
| `--no-turnstile` | Bez konfiguracji Turnstile | |

### Przykłady konfiguracji

```bash
# Pełna interaktywna konfiguracja
./local/setup-sellf-config.sh

# Szybka konfiguracja z automatyczną domeną Cytrus
./local/setup-sellf-config.sh --ssh=mikrus --domain=auto

# Bez Stripe i Turnstile (tylko Supabase)
./local/setup-sellf-config.sh --ssh=mikrus --no-stripe --no-turnstile

# Z konkretnym projektem Supabase
./local/setup-sellf-config.sh --ssh=mikrus --supabase-project=grinnleqqyygznnbpjzc --domain=auto

# Z własną domeną Cloudflare
./local/setup-sellf-config.sh --ssh=mikrus --domain=shop.example.com --domain-type=cloudflare
```

---

## Parametry deploy.sh (dla Sellf)

### Obowiązkowe

| Parametr | Opis |
|----------|------|
| `--ssh=ALIAS` | SSH alias serwera z ~/.ssh/config |

### Opcjonalne - Supabase

| Parametr | Opis |
|----------|------|
| `--supabase-project=REF` | Project ref - pomija interaktywny wybór |

### Opcjonalne - Domena

| Parametr | Opis |
|----------|------|
| `--domain=DOMAIN` | Domena aplikacji lub `auto` dla automatycznej Cytrus |
| `--domain-type=TYPE` | `cytrus` (subdomena *.byst.re) lub `cloudflare` (własna domena) |

### Opcjonalne - Tryby

| Parametr | Opis |
|----------|------|
| `--yes` | Tryb automatyczny - bez pytań |
| `--update` | Aktualizacja istniejącej instalacji |
| `--build-file=PATH` | Użyj lokalnego pliku .tar.gz (dla prywatnych repo) |
| `--dry-run` | Pokaż co się wykona bez wykonania |

### Przykłady

```bash
# Interaktywny z automatyczną domeną
./local/deploy.sh sellf --ssh=mikrus --domain=auto --domain-type=cytrus

# Automatyczny (wymaga wcześniejszej konfiguracji)
./local/deploy.sh sellf --ssh=mikrus --yes

# Automatyczny z konkretnym projektem Supabase
./local/deploy.sh sellf --ssh=mikrus --supabase-project=abc123 --yes

# Z własną domeną Cloudflare
./local/deploy.sh sellf --ssh=mikrus --domain=shop.example.com --domain-type=cloudflare --yes

# Aktualizacja
./local/deploy.sh sellf --ssh=mikrus --update

# Z lokalnym buildem (prywatne repo)
./local/deploy.sh sellf --ssh=mikrus --build-file=~/Downloads/sellf-build.tar.gz --yes
```

---

## Case Studies

### Case 1: Pierwsza instalacja (początkujący)

**Sytuacja:** Pierwszy raz instalujesz Sellf, chcesz żeby skrypt prowadził za rączkę.

```bash
# Po prostu uruchom
./local/deploy.sh sellf --ssh=mikrus

# Skrypt:
# 1. Otworzy przeglądarkę do logowania Supabase
# 2. Pokaże listę projektów do wyboru
# 3. Zapyta o klucze Stripe (możesz pominąć)
# 4. Zapyta o domenę (wybierz automatyczną)
# 5. Zainstaluje i uruchomi
```

### Case 2: Deployment na CI/CD

**Sytuacja:** Chcesz automatyzować deployment w pipeline CI/CD.

```bash
# JEDNORAZOWO (na lokalnej maszynie):
./local/setup-sellf-config.sh --ssh=mikrus --domain=auto

# W CI/CD:
./local/deploy.sh sellf --ssh=mikrus --yes
```

### Case 3: Wiele serwerów Mikrus

**Sytuacja:** Masz kilka serwerów i chcesz szybko deployować na różne.

```bash
# Konfiguracja dla każdego serwera
./local/setup-sellf-config.sh --ssh=mikrus --domain=auto
./local/setup-sellf-config.sh --ssh=gracz --domain=auto

# Deploy (użyje zapisanej konfiguracji)
./local/deploy.sh sellf --ssh=mikrus --yes
./local/deploy.sh sellf --ssh=gracz --yes
```

### Case 4: Własna domena z Cloudflare

**Sytuacja:** Masz domenę `shop.mojastrona.pl` z DNS w Cloudflare.

```bash
# 1. W Cloudflare: dodaj rekord A wskazujący na IP serwera Mikrus
#    shop.mojastrona.pl → 1.2.3.4 (IP z panelu Mikrus)

# 2. Konfiguracja
./local/setup-sellf-config.sh \
  --ssh=mikrus \
  --domain=shop.mojastrona.pl \
  --domain-type=cloudflare

# 3. Deploy
./local/deploy.sh sellf --ssh=mikrus --yes
```

### Case 5: Wiele projektów Supabase na jednym koncie

**Sytuacja:** Masz dwa projekty Supabase: produkcyjny i testowy.

```bash
# Project ref znajdziesz w URL:
# https://supabase.com/dashboard/project/TUTAJ_REF

# Deploy na projekt testowy
./local/deploy.sh sellf --ssh=mikrus-staging --supabase-project=abc123test --yes

# Deploy na projekt produkcyjny
./local/deploy.sh sellf --ssh=mikrus-prod --supabase-project=xyz789prod --yes
```

### Case 6: Reinstalacja po wyczyszczeniu serwera

**Sytuacja:** Wyczyściłeś serwer, ale masz zapisaną konfigurację.

```bash
# Konfiguracja jest w ~/.config/sellf/deploy-config.env
# Po prostu uruchom:
./local/deploy.sh sellf --ssh=mikrus --yes

# Skrypt użyje zapisanych kluczy Supabase, domeny, etc.
```

### Case 7: Aktualizacja Sellf

**Sytuacja:** Wyszła nowa wersja, chcesz zaktualizować.

```bash
# Prosta aktualizacja (auto-wykrywa instancję)
./local/deploy.sh sellf --ssh=mikrus --update

# Aktualizacja konkretnej instancji
./local/deploy.sh sellf --ssh=mikrus --update --domain=shop.example.com

# Aktualizacja z lokalnym buildem (prywatne repo)
./local/deploy.sh sellf --ssh=mikrus --update --build-file=~/Downloads/sellf-build.tar.gz
```

### Case 8: Wiele instancji na jednym serwerze (ta sama baza)

**Sytuacja:** Chcesz uruchomić kilka sklepów na jednym Mikrusie, używając tego samego projektu Supabase.

```bash
# Pierwsza instancja - sklep główny
./local/deploy.sh sellf --ssh=mikrus --domain=shop.example.com --domain-type=cloudflare

# Druga instancja - kursy online
./local/deploy.sh sellf --ssh=mikrus --domain=courses.example.com --domain-type=cloudflare

# Trzecia instancja - inna domena
./local/deploy.sh sellf --ssh=mikrus --domain=digital.innadomena.pl --domain-type=cloudflare
```

**Wynik na serwerze:**
```
/opt/stacks/sellf-shop/      # PM2: sellf-shop,    port: 3333
/opt/stacks/sellf-courses/   # PM2: sellf-courses, port: 3334
/opt/stacks/sellf-digital/   # PM2: sellf-digital, port: 3335
```

Każda instancja:
- Ma własny katalog i proces PM2
- Może mieć własną konfigurację Stripe
- Port jest auto-inkrementowany (3333, 3334, 3335...)

**Aktualizacja konkretnej instancji:**
```bash
./local/deploy.sh sellf --ssh=mikrus --update --domain=courses.example.com
```

### Case 9: Wiele instancji z różnymi bazami danych

**Sytuacja:** Chcesz mieć całkowicie niezależne sklepy - każdy z własną bazą Supabase.

```bash
# Sprawdź swoje projekty Supabase
# https://supabase.com/dashboard/projects

# Instancja 1: Produkcja (projekt: sellf-prod)
./local/deploy.sh sellf --ssh=mikrus \
  --supabase-project=abc123prod \
  --domain=shop.example.com \
  --domain-type=cloudflare \
  --yes

# Instancja 2: Testy (projekt: sellf-test)
./local/deploy.sh sellf --ssh=mikrus \
  --supabase-project=xyz789test \
  --domain=test.example.com \
  --domain-type=cloudflare \
  --yes

# Instancja 3: Demo dla klienta (projekt: sellf-demo)
./local/deploy.sh sellf --ssh=mikrus \
  --supabase-project=demo456client \
  --domain=demo.example.com \
  --domain-type=cloudflare \
  --yes
```

**Wynik na serwerze:**
```
/opt/stacks/sellf-shop/   # Supabase: abc123prod,  port: 3333
/opt/stacks/sellf-test/   # Supabase: xyz789test,  port: 3334
/opt/stacks/sellf-demo/   # Supabase: demo456client, port: 3335
```

**Kluczowy parametr:** `--supabase-project=REF` pozwala wybrać inny projekt Supabase dla każdej instancji.

**Weryfikacja konfiguracji:**
```bash
# Sprawdź który projekt używa która instancja
ssh mikrus "grep SUPABASE_URL /opt/stacks/sellf-*/admin-panel/.env.local"
```

---

## Gdzie są zapisywane klucze

### Na lokalnej maszynie

```
~/.config/sellf/
├── deploy-config.env    # Główna konfiguracja (setup-sellf-config.sh)
└── supabase.env         # Backup kluczy Supabase

~/.config/supabase/
└── access_token         # Personal Access Token Supabase

~/.config/cloudflare/
├── turnstile_token      # API token Cloudflare
├── turnstile_account_id # Account ID
└── turnstile_keys_DOMENA # Klucze Turnstile per domena
```

### Na serwerze

```
# Pojedyncza instancja (auto-domena lub pierwsza instalacja)
~/sellf/
├── admin-panel/
│   ├── .env.local           # Konfiguracja aplikacji
│   └── .next/standalone/    # Zbudowana aplikacja
└── .env.local.backup        # Backup (przy update)

# Multi-instance (każda domena = osobny katalog)
~/sellf-shop/             # domena: shop.example.com
~/sellf-courses/          # domena: courses.example.com
~/sellf-demo/             # domena: demo.example.com
```

---

## Zarządzanie

```bash
# Status wszystkich instancji
ssh mikrus "pm2 status"

# Logi pojedynczej instancji
ssh mikrus "pm2 logs sellf-admin"           # auto-domena
ssh mikrus "pm2 logs sellf-shop"            # shop.example.com

# Restart
ssh mikrus "pm2 restart sellf-admin"

# Restart wszystkich instancji Sellf
ssh mikrus "pm2 restart all"

# Logi na żywo
ssh mikrus "pm2 logs sellf-shop --lines 50"

# Sprawdź konfigurację Supabase wszystkich instancji
ssh mikrus "grep SUPABASE_URL /opt/stacks/sellf*/admin-panel/.env.local"
```

> **Uwaga:** Jeśli `pm2: command not found`, dodaj PATH ręcznie:
> ```bash
> ssh mikrus "echo 'export PATH=\"\$HOME/.bun/bin:\$PATH\"' >> ~/.bashrc"
> ```
> Nowe instalacje Sellf dodają to automatycznie.

---

## Dodatkowe skrypty

### setup-turnstile.sh - CAPTCHA

```bash
# Automatycznie tworzy widget Turnstile dla domeny
./local/setup-turnstile.sh shop.example.com mikrus
```

### setup-supabase-email.sh - SMTP

```bash
# Konfiguruje własny SMTP dla wysyłki emaili
./local/setup-supabase-email.sh
```

### setup-supabase-migrations.sh - Migracje bazy

```bash
# Ręczne uruchomienie migracji (normalnie automatyczne)
SSH_ALIAS=mikrus ./local/setup-supabase-migrations.sh
```

---

## Stripe Webhooks (po instalacji)

1. Otwórz: https://dashboard.stripe.com/webhooks
2. Add endpoint: `https://TWOJA-DOMENA/api/webhooks/stripe`
3. Events:
   - `checkout.session.completed`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Skopiuj Signing Secret (`whsec_...`)
5. Dodaj do konfiguracji:
   ```bash
   ssh mikrus "echo 'STRIPE_WEBHOOK_SECRET=whsec_...' >> ~/sellf/admin-panel/.env.local"
   ssh mikrus "pm2 restart sellf-admin"
   ```

---

## FAQ

**Q: Jaka jest różnica między trybem interaktywnym a automatycznym?**

A: Interaktywny zadaje pytania krok po kroku - idealny na początek. Automatyczny używa zapisanych kluczy i flagi `--yes` - idealny do CI/CD i powtarzalnych deployów.

**Q: Czy muszę uruchamiać setup-sellf-config.sh przed każdym deployem?**

A: Nie! Wystarczy raz. Konfiguracja jest zapisywana i używana automatycznie przy kolejnych deployach z `--yes`.

**Q: Co jeśli chcę zmienić projekt Supabase?**

A: Uruchom ponownie `./local/setup-sellf-config.sh` i wybierz inny projekt, lub użyj `--supabase-project=NOWY_REF`.

**Q: Czy pierwszy user to admin?**

A: Tak! Pierwsza osoba która się zarejestruje automatycznie dostaje uprawnienia admina.

**Q: Testowa karta do Stripe?**

A: `4242 4242 4242 4242` (dowolna data, dowolne CVC)

**Q: Gdzie znajdę project ref Supabase?**

A: W URL projektu: `https://supabase.com/dashboard/project/TUTAJ_REF`

**Q: Czy Turnstile jest obowiązkowy?**

A: Nie. To opcjonalna ochrona CAPTCHA. Możesz skonfigurować później lub pominąć.

**Q: Czy mogę mieć kilka instancji Sellf na jednym serwerze?**

A: Tak! Każda instancja musi mieć inną domenę. System automatycznie:
- Tworzy oddzielny katalog (`/opt/stacks/sellf-{subdomena}/`)
- Przydziela kolejny port (3333, 3334, 3335...)
- Tworzy oddzielny proces PM2

Możesz też użyć różnych projektów Supabase dla każdej instancji za pomocą `--supabase-project=REF`.

**Q: Jak sprawdzić status wielu instancji?**

A: `ssh mikrus "pm2 list"` - pokaże wszystkie procesy Sellf z ich statusem.

---

## Czy Mikrus za 35 zł/rok wystarczy dla mojego sklepu?

**Tak.** Sprawdziliśmy to w praktyce.

Przetestowaliśmy Sellf na najtańszym planie Mikrusa (384 MB RAM, 35 zł/rok), symulując ruch jak po wrzuceniu linku do sklepu w mediach społecznościowych.

| Scenariusz | Czas ładowania strony | Błędy |
|---|:---:|:---:|
| Normalny ruch (kilka osób naraz) | poniżej 0,5 s | brak |
| Większy ruch (30 osób jednocześnie) | ok. 0,7 s | brak |
| Duży ruch (50 osób jednocześnie) | ok. 1 s | brak |
| Viral (100 osób jednocześnie) | ok. 2 s | brak |

**Przy 100 osobach jednocześnie na stronie - zero błędów, zero niedostępności.** Sklep działa, klienci mogą kupować.

Dla porównania: większość małych sklepów internetowych ma kilka-kilkanaście osób jednocześnie. 100 concurrent to scenariusz rodem z kampanii reklamowej lub posta który "poszedł w viral". Nawet wtedy - działa.

> Sellf na Mikrusie 1.0 za 35 zł/rok to realny wybór dla twórcy cyfrowego z listą do kilku tysięcy subskrybentów, który chce sprzedawać e-booki, kursy czy szablony bez płacenia prowizji platformom.

---

## Czy darmowy Supabase wystarczy?

Sellf używa Supabase tylko jako bazy danych i systemu autoryzacji. Jeśli materiały (pliki, wideo) hostowane są na zewnętrznym CDN, Supabase nie obsługuje żadnego ruchu pobierania - tylko dane sklepu.

**Szacunkowe zużycie bazy dla małego sklepu** (20 produktów, 1000 użytkowników, 100 transakcji/miesiąc):

| | Rok 1 | Rok 2 | Rok 3 |
|---|:---:|:---:|:---:|
| Produkty, konfiguracja | ~100 KB | ~200 KB | ~300 KB |
| Użytkownicy i dostępy | ~2.5 MB | ~5 MB | ~7 MB |
| Transakcje i płatności | ~1.3 MB | ~2.6 MB | ~4 MB |
| Logi (audit, webhooki) | ~30 MB | ~60 MB | ~90 MB |
| Eventy wideo i analityka | ~10 MB | ~24 MB | ~36 MB |
| Indeksy PostgreSQL | ~45 MB | ~90 MB | ~135 MB |
| **Razem** | **~90 MB** | **~180 MB** | **~270 MB** |

Darmowy plan Supabase daje 500 MB bazy danych i 50,000 aktywnych użytkowników miesięcznie. **Dla typowego małego sklepu cyfrowego wystarczy na 3-4 lata.**

**Przy jakich przychodach darmowy Supabase przestaje wystarczać?**

Ograniczeniem jest limit **50,000 aktywnych użytkowników miesięcznie** (MAU - osoby które się zalogowały w danym miesiącu, nie wszystkie zarejestrowane). Baza danych przy takiej skali pozostaje daleko poniżej limitu 500 MB.

| Etap sklepu | Aktywni użytkownicy/mies | Sprzedaż/mies | Przychód/mies | Serwer | Supabase |
|---|:---:|:---:|:---:|:---:|:---:|
| Start | ~200 | ~15 szt. | ~750 zł | bez problemu | bez problemu |
| Rosnący sklep | ~1,000 | ~50 szt. | ~5,000 zł | bez problemu | bez problemu |
| Stabilny sklep | ~3,000 | ~100 szt. | ~10,000 zł | bez problemu | bez problemu |
| Rozważ mocniejszy serwer | ~10,000+ | ~300 szt. | ~30,000 zł | zależy od ruchu* | bez problemu |
| Upgrade Supabase | ~50,000+ | ~1,000 szt. | ~100,000 zł | wymaga większego VPS | limit MAU |

*Przy ~3,000 MAU ruch jest rozłożony w czasie i serwer radzi sobie bez problemu. Przy ~10,000+ MAU wszystko zależy od charakteru sprzedaży: subskrybenci rozproszeni w czasie to jedno, premiera produktu z mailingiem do 10,000 osób to drugie. Na takie sytuacje warto rozważyć mocniejszy plan lub PM2 cluster.

Innymi słowy: przy kosztach infrastruktury 35 zł rocznie możesz spokojnie prowadzić sklep generujący **kilka tysięcy złotych miesięcznie**. Upgrade staje się tematem dopiero przy poważnym wzroście - a wtedy masz już budżet żeby nawet nie zauważyć tego kosztu.

Gdy sklep urośnie i darmowy plan przestanie wystarczać, naturalnym krokiem jest **własna instancja Supabase** - toolbox ma gotowy instalator:

```bash
./local/deploy.sh supabase --ssh=ALIAS --domain=db.example.com
```

Supabase self-hosted wymaga minimum 2 GB RAM (za dużo na Mikrus 1.0), ale działa świetnie na VPS za kilkanaście euro miesięcznie (np. Hetzner CAX11). Szczegóły: [apps/supabase/README.md](../supabase/README.md).

---

## Porównanie kosztów

| | EasyCart | Gumroad | **Sellf** |
|---|---|---|---|
| Opłata miesięczna | 100 zł/mies | 10$/mies | **0 zł** |
| Prowizja od sprzedaży | 1-3% | 10% | **0%** |
| Własność danych | - | - | **Tak** |
| Przy 300k zł/rok | ~16-19k zł | ~30k zł | **~8.7k zł** |

**Oszczędzasz 7,000-20,000 zł rocznie** hostując Sellf na Mikrusie.

---

> Sellf: https://github.com/jurczykpawel/sellf
