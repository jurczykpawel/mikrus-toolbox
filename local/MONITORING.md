# Monitorowanie Sellf

Przewodnik po narzędziach do monitorowania wydajności i zużycia zasobów przez aplikację Sellf na serwerze Mikrus.

## 🎯 Szybki Start

### Podstawowe monitorowanie PM2

```bash
# Status aplikacji
ssh mikrus "pm2 status"

# Monitoring w czasie rzeczywistym
ssh mikrus "pm2 monit"

# Logi (ostatnie 50 linii)
ssh mikrus "pm2 logs sellf-admin --lines 50"
```

### Pełny benchmark (test + monitoring)

```bash
# Uruchom jedną komendą
./local/benchmark-sellf.sh https://shop.byst.re mikrus

# Z większym obciążeniem
./local/benchmark-sellf.sh https://shop.byst.re mikrus 500 30
```

## 📊 Dostępne Narzędzia

### 1. monitor-sellf.sh

Ciągłe monitorowanie zużycia CPU i RAM przez aplikację Sellf.

**Użycie:**
```bash
./local/monitor-sellf.sh <ssh_alias> [czas_w_sekundach] [nazwa_app]
```

**Przykłady:**
```bash
# Monitoruj przez 60 sekund (domyślnie)
./local/monitor-sellf.sh mikrus

# Monitoruj przez 5 minut
./local/monitor-sellf.sh mikrus 300

# Konkretna instancja (multi-instance setup)
./local/monitor-sellf.sh mikrus 300 sellf-shop
```

**Output:**
- Metryki w czasie rzeczywistym (progress bar)
- Plik CSV z danymi: `sellf-metrics-YYYYMMDD-HHMMSS.csv`
- Podsumowanie: CPU/RAM (max, średnia)
- Rekomendacja: czy aplikacja zmieści się na Mikrus 3.0

**Kolumny CSV:**
- `timestamp` - Data i czas pomiaru
- `cpu_percent` - Wykorzystanie CPU (%)
- `memory_mb` - Pamięć RAM (MB)
- `memory_percent` - Procent dostępnej pamięci
- `uptime_min` - Czas działania (minuty)
- `restarts` - Liczba restartów
- `status` - Status procesu (online/stopped)

**Wizualizacja:**
1. Otwórz plik CSV w Excel/Google Sheets
2. Zaznacz kolumny: `timestamp`, `cpu_percent`, `memory_mb`
3. Wstaw → Wykres → Wykres liniowy
4. Masz wykres zużycia zasobów w czasie!

---

### 2. load-test-sellf.sh

Test obciążeniowy aplikacji - symuluje ruch użytkowników.

**Użycie:**
```bash
./local/load-test-sellf.sh <url> [liczba_requestów] [współbieżność]
```

**Przykłady:**
```bash
# Podstawowy test (50 requestów, 5 współbieżnych)
./local/load-test-sellf.sh https://shop.byst.re

# Test średni (100 requestów, 10 współbieżnych)
./local/load-test-sellf.sh https://shop.byst.re 100 10

# Test duży (500 requestów, 20 współbieżnych)
./local/load-test-sellf.sh https://shop.byst.re 500 20

# Stress test (1000 requestów, 50 współbieżnych)
./local/load-test-sellf.sh https://shop.byst.re 1000 50
```

**Scenariusz testu (realistyczny mikst endpointów):**
- 20% - Strona główna
- 30% - Lista produktów
- 30% - Szczegóły produktu
- 20% - Profil użytkownika

**Output:**
- Progress bar w czasie rzeczywistym
- Success rate (% udanych requestów)
- Czasy odpowiedzi: min/średnia/max
- Ocena wydajności:
  - ✅ < 500ms - Świetna
  - ⚠️ 500-1000ms - Dobra
  - 🔶 1-2s - Przeciętna
  - 🔥 > 2s - Słaba

**Interpretacja wyników:**

| Średni czas | Ocena | Uwagi |
|-------------|-------|-------|
| < 300ms | Znakomita | Aplikacja bardzo szybka |
| 300-500ms | Świetna | Doskonała wydajność |
| 500-800ms | Dobra | Akceptowalna dla większości użytkowników |
| 800-1500ms | Średnia | Użytkownicy mogą odczuwać opóźnienia |
| > 1500ms | Słaba | Wymaga optymalizacji |

---

### 3. benchmark-sellf.sh

**Najlepsze narzędzie!** Łączy test obciążeniowy + monitoring zasobów.

**Użycie:**
```bash
./local/benchmark-sellf.sh <url> <ssh_alias> [requesty] [współbieżność]
```

**Przykłady:**
```bash
# Szybki benchmark (100 requestów)
./local/benchmark-sellf.sh https://shop.byst.re mikrus

# Średni benchmark (200 requestów, 20 współbieżnych)
./local/benchmark-sellf.sh https://shop.byst.re mikrus 200 20

# Duży benchmark (500 requestów, 30 współbieżnych)
./local/benchmark-sellf.sh https://shop.byst.re mikrus 500 30
```

**Co robi:**
1. Pobiera snapshot zasobów PRZED testem
2. Uruchamia monitoring w tle
3. Wykonuje test obciążeniowy
4. Pobiera snapshot zasobów PO teście
5. Generuje kompletny raport

**Output (folder `benchmark-YYYYMMDD-HHMMSS/`):**
- `REPORT.txt` - Kompletny raport tekstowy
- `sellf-metrics-*.csv` - Dane do wykresu
- `load-test.log` - Szczegółowe logi testu
- `monitoring.log` - Szczegółowe logi monitoringu

**Raport zawiera:**
- Porównanie zasobów przed/po teście
- Zmiana zużycia CPU i RAM
- Wyniki testu obciążeniowego
- Podsumowanie metryk
- Rekomendacje

---

## 🎬 Praktyczne Przykłady

### Case 1: "Sprawdzenie czy zmieści się na Mikrus 3.0"

```bash
# 1. Zainstaluj aplikację na testowym serwerze
./local/deploy.sh sellf --ssh=mikrus --domain=auto

# 2. Uruchom benchmark
./local/benchmark-sellf.sh https://test.byst.re mikrus 200 20

# 3. Sprawdź raport
cat benchmark-*/REPORT.txt

# 4. Szukaj w raporcie:
#    - Max RAM < 500 MB? ✅ Zmieści się
#    - Max RAM 500-700 MB? ⚠️ Dopuszczalne
#    - Max RAM > 700 MB? 🔥 Potrzeba Mikrus 3.0 (2GB)
```

### Case 2: "Jak zachowuje się pod obciążeniem?"

```bash
# 1. Uruchom długi monitoring (10 minut)
./local/monitor-sellf.sh mikrus 600 &

# 2. W drugim terminalu - test obciążeniowy
./local/load-test-sellf.sh https://shop.byst.re 1000 50

# 3. Poczekaj aż monitoring się zakończy

# 4. Otwórz CSV w Excel i zobacz wykres
#    Szukaj:
#    - Czy RAM rośnie liniowo? (memory leak?)
#    - Czy CPU spada po teście? (czy wraca do idle?)
#    - Czy były restarty? (kolumna 'restarts')
```

### Case 3: "Porównanie przed i po optymalizacji"

```bash
# PRZED optymalizacją
./local/benchmark-sellf.sh https://shop.byst.re mikrus 300 30
mv benchmark-* benchmark-before/

# ... (wprowadzasz zmiany) ...

# PO optymalizacji
./local/benchmark-sellf.sh https://shop.byst.re mikrus 300 30
mv benchmark-* benchmark-after/

# Porównanie
diff benchmark-before/REPORT.txt benchmark-after/REPORT.txt
```

### Case 4: "Monitorowanie produkcji (ciągłe)"

Użyj PM2 Plus (darmowy dashboard):

```bash
# 1. Zarejestruj się: https://app.pm2.io
# 2. Utwórz bucket (darmowy)
# 3. Na serwerze:
ssh mikrus "pm2 link <SECRET_KEY> <PUBLIC_KEY>"

# Teraz masz:
# - Dashboard w przeglądarce
# - Wykresy CPU/RAM w czasie rzeczywistym
# - Historia metryk (24h na darmowym planie)
# - Alerty email przy błędach
```

---

## 🔍 Diagnostyka Problemów

### Problem: Wysoki RAM (> 500 MB na małym ruchu)

**Sprawdź:**
```bash
# Czy są memory leaki?
./local/monitor-sellf.sh mikrus 600  # 10 minut
# Otwórz CSV i zobacz czy RAM ciągle rośnie
```

**Możliwe przyczyny:**
- Next.js cache rośnie bez limitu
- Supabase client nie jest reużywany
- WebSocket connections nie są zamykane

**Rozwiązanie:**
- Dodaj `NODE_OPTIONS='--max-old-space-size=512'` w PM2 config
- Zrestartuj: `ssh mikrus "pm2 restart sellf-admin"`

### Problem: Wysoki CPU w idle (> 5% bez ruchu)

**Sprawdź:**
```bash
# Snapshot bez ruchu
ssh mikrus "pm2 list"
ssh mikrus "pm2 monit"  # Patrz przez 2 minuty

# Logi - szukaj powtarzających się operacji
ssh mikrus "pm2 logs sellf-admin --lines 200"
```

**Możliwe przyczyny:**
- Polling do Supabase
- Nieoptymalne queries w Next.js Middleware
- Hot reload (DEV mode - nie powinno być na produkcji!)

**Rozwiązanie:**
- Sprawdź `NODE_ENV`: `ssh mikrus "grep NODE_ENV ~/sellf/admin-panel/.env.local"`
- Musi być `NODE_ENV=production`!

### Problem: Wolne czasy odpowiedzi (> 1s średnia)

**Sprawdź:**
```bash
# Test z różnych lokalizacji
./local/load-test-sellf.sh https://shop.byst.re 50 5

# Sprawdź czy wolne są wszystkie endpointy czy tylko niektóre
curl -w "@curl-format.txt" -o /dev/null -s https://shop.byst.re
curl -w "@curl-format.txt" -o /dev/null -s https://shop.byst.re/products
```

**Możliwe przyczyny:**
- Brak cache na Cloudflare (sprawdź cache rules)
- Nieoptymalne queries do Supabase
- Brak indeksów w bazie danych
- Mikrus przeciążony (sprawdź `ssh mikrus "htop"`)

**Rozwiązanie:**
```bash
# Włącz Cloudflare cache
./local/setup-cloudflare-optimize.sh shop.byst.re

# Sprawdź Supabase query performance
# Dashboard → Performance → Query Insights
```

### Problem: Aplikacja crashuje przy obciążeniu

**Sprawdź:**
```bash
# Test stopniowego obciążenia
./local/load-test-sellf.sh https://shop.byst.re 10 2   # OK?
./local/load-test-sellf.sh https://shop.byst.re 50 5   # OK?
./local/load-test-sellf.sh https://shop.byst.re 100 10 # Crash?

# Logi podczas crashu
ssh mikrus "pm2 logs sellf-admin --lines 500 --err"

# Sprawdź ilość restartów
ssh mikrus "pm2 show sellf-admin"
```

**Możliwe przyczyny:**
- Za mało RAM (OOM Killer)
- Nieobsłużone promise rejections
- Timeout na DB connections

**Rozwiązanie:**
- Zwiększ RAM limit: Mikrus 3.0 (2GB)
- Dodaj error handling w API routes
- Zwiększ connection pool Supabase

---

## 📈 Metryki Referencyjne

### Mikrus 2.1 (1GB RAM)

| Metryka | Idle | Mały ruch | Średni ruch | Duży ruch |
|---------|------|-----------|-------------|-----------|
| RAM | 250-300 MB | 300-400 MB | 400-500 MB | 500-600 MB |
| CPU | 1-3% | 5-15% | 15-30% | 30-60% |
| Response time | 100-200ms | 200-400ms | 400-800ms | 800-1500ms |
| Concurrent users | - | ~5 | ~10-15 | ~20-30 |

### Mikrus 3.0 (2GB RAM)

| Metryka | Idle | Mały ruch | Średni ruch | Duży ruch |
|---------|------|-----------|-------------|-----------|
| RAM | 250-300 MB | 300-450 MB | 450-700 MB | 700-1000 MB |
| CPU | 1-3% | 5-15% | 15-30% | 30-60% |
| Response time | 100-200ms | 200-350ms | 350-600ms | 600-1000ms |
| Concurrent users | - | ~10 | ~20-30 | ~50-80 |

**Uwaga:** To wartości dla standardowego Sellf z Supabase. Twoje wyniki mogą się różnić w zależności od:
- Ilości produktów
- Złożoności zapytań
- Rozmiaru zdjęć
- Zewnętrznych integracji (Stripe, Turnstile)

---

## 🎓 Najlepsze Praktyki

### 1. Regularny monitoring

```bash
# Codziennie sprawdzaj
ssh mikrus "pm2 status"

# Co tydzień - pełny raport
./local/benchmark-sellf.sh https://shop.byst.re mikrus 100 10

# Trzymaj historię
mkdir -p benchmarks/
mv benchmark-* benchmarks/
```

### 2. Alerty

Skonfiguruj PM2 Plus (darmowy) dla alertów:
- Aplikacja down > 2 minuty
- CPU > 80% przez 5 minut
- RAM > 90% przez 3 minuty
- Więcej niż 3 restarty w ciągu godziny

### 3. Optymalizacja progresywna

1. **Baseline** - pierwszy benchmark (zapisz jako punkt odniesienia)
2. **Cache** - włącz Cloudflare cache (`setup-cloudflare-optimize.sh`)
3. **Benchmark** - czy pomogło?
4. **Images** - optymalizuj zdjęcia (WebP, lazy loading)
5. **Benchmark** - czy pomogło?
6. **Queries** - zoptymalizuj Supabase queries
7. **Benchmark** - czy pomogło?

**Rób tylko jedną zmianę na raz!** Wtedy wiesz co pomogło.

### 4. Testy przed wdrożeniem

```bash
# Przed każdym update
./local/benchmark-sellf.sh https://test.byst.re mikrus 200 20

# Jeśli wyniki OK - deploy na produkcję
./local/deploy.sh sellf --ssh=mikrus-prod --update

# Po deployu - sprawdź czy nie pogorszyło się
./local/benchmark-sellf.sh https://shop.example.com mikrus-prod 200 20
```

---

## 🔗 Dodatkowe Narzędzia

### PM2 Keymetrics (darmowy)

```bash
ssh mikrus "pm2 link <SECRET> <PUBLIC>"
```

**Dashboard:** https://app.pm2.io

**Daje:**
- Wykresy metryk (24h history)
- Alerty email/Slack
- Error tracking
- Log management
- Remote restart/reload

### Grafana + Prometheus (zaawansowane)

Jeśli potrzebujesz profesjonalnego monitoringu:
1. Zainstaluj `prom-client` w Sellf
2. Expose `/metrics` endpoint
3. Skonfiguruj Prometheus na Mikrusie
4. Podłącz Grafana

**Dokumentacja:** https://github.com/siimon/prom-client

---

## ❓ FAQ

**Q: Czy mogę monitorować wiele instancji jednocześnie?**

A: Tak! Benchmark każdą osobno:
```bash
./local/benchmark-sellf.sh https://shop1.example.com mikrus
./local/benchmark-sellf.sh https://shop2.example.com mikrus
```

**Q: Jak często powinienem robić benchmark?**

A:
- **Po każdym update** - upewnij się że nie pogorszyło się
- **Raz w tygodniu** - śledź trend
- **Przed skalowaniem** - czy potrzeba upgrade?

**Q: Co zrobić jeśli testy pokazują za wysokie zużycie RAM?**

A:
1. Sprawdź czy nie ma memory leaków (monitoruj przez 10 min)
2. Zoptymalizuj cache (dodaj limity)
3. Jeśli nic nie pomaga - upgrade na Mikrus 3.0

**Q: Jak symulować jeszcze większe obciążenie?**

A: Użyj `ab` (Apache Bench) lub `wrk`:
```bash
# Zainstaluj
brew install wrk  # macOS
apt install wrk   # Linux

# Test
wrk -t12 -c400 -d30s https://shop.byst.re
```

**Q: Czy te skrypty działają z innymi aplikacjami (nie tylko Sellf)?**

A: Tak! Wszystkie skrypty PM2 działają z każdą aplikacją zarządzaną przez PM2. Podaj tylko nazwę procesu:
```bash
./local/monitor-sellf.sh mikrus 300 n8n-server
./local/monitor-sellf.sh mikrus 300 uptime-kuma
```

---

**💡 Pro Tip:** Uruchom benchmark przed zakupem Mikrusa. Zainstaluj Sellf na darmowym serwisie (Railway, Render free tier) i uruchom `benchmark-sellf.sh`. Jeśli RAM < 500 MB - Mikrus 2.1 wystarczy. Jeśli RAM > 500 MB - potrzeba Mikrus 3.0.
