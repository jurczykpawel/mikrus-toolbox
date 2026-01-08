# 🧰 Mikrus Toolbox

**Zestaw narzędzi "Lazy Engineer" dla Solopreneurów.** 🚀
Zbuduj niezależną, profesjonalną infrastrukturę firmy za ~20 zł miesięcznie, zamiast płacić 2000 zł za subskrypcje SaaS.

> 💡 **Wolisz klikać niż wpisywać komendy?**
> Sprawdź **[Mikrus n8n Manager](https://manager.cytr.us/)** – nasze narzędzie z interfejsem graficznym (GUI), które zainstaluje n8n za Ciebie jednym kliknięciem. Idealne na start!

---

## 🎯 Dla kogo to jest? (Persona: Kamil)
Jesteś przedsiębiorcą, twórcą, freelancerem.
- **Masz dość "podatku od sukcesu":** Im więcej sprzedajesz, tym droższy jest Twój CRM, mailing i Zapier.
- **Chcesz niezależności:** Twoje dane to Twoja własność. Nie chcesz, żeby awaria chmury w USA położyła Twój biznes.
- **Szukasz dźwigni:** Chcesz automatyzować nudną pracę, żeby skupić się na strategii.
- **Jesteś oszczędny, ale nie skąpy:** Wolisz zainwestować raz w konfigurację, niż płacić abonament do końca życia.

Ten toolbox zamienia tani serwer VPS (np. [Mikrus.pl](https://mikrus.pl)) w potężną maszynę klasy Enterprise.

---

## 🛠️ Twój Cyfrowy Arsenał (Co tu jest?)

Przygotowaliśmy gotowe skrypty instalacyjne ("One-Click"), które stawiają usługi zoptymalizowane pod małe zasoby (mało RAM-u, mały dysk).

### 🤖 Automatyzacja & Operacje
| Narzędzie | Zastępuje | Opis |
| :--- | :--- | :--- |
| **n8n** | Make / Zapier | Mózg Twojej firmy. Łączy wszystko ze wszystkim. Wersja zoptymalizowana pod zewnętrzną bazę danych (oszczędza RAM). |
| **Dockge** | Portainer | Panel sterowania. Zarządzaj wszystkimi usługami przez przeglądarkę, widząc pliki konfiguracyjne. |
| **Uptime Kuma** | UptimeRobot | Twój stróż nocny. Sprawdza czy Twoje strony działają i wysyła alarm, gdy coś padnie. |
| **ntfy** | Pushover | Serwer powiadomień PUSH. Wysyłaj alerty z n8n prosto na telefon. |
| **Redis** | - | Pamięć podręczna (cache). Przyspiesza n8n i inne aplikacje. |
| **MCP Docker** | - | Most AI ↔ Serwer. Pozwól Claude/Cursor zarządzać kontenerami przez SSH. |
| **Power Tools** | - | Zestaw CLI (`yt-dlp`, `ffmpeg`, `pup`) do zaawansowanej automatyzacji na serwerze. |

### 💰 Marketing & Sprzedaż
| Narzędzie | Zastępuje | Opis |
| :--- | :--- | :--- |
| **GateFlow** | EasyCart / Gumroad | **Twój własny sklep z produktami cyfrowymi.** E-booki, kursy, szablony. 0 zł/mies, 0% prowizji. Lejki, OTO, kupony, Omnibus EU. |
| **Listmonk** | Mailchimp / ActiveCampaign | System newsletterowy. Wysyłaj miliony maili za grosze (przez Amazon SES lub inny SMTP). |
| **Typebot** | Typeform | Interaktywne formularze i chatboty. Zbieraj leady, rób ankiety, sprzedawaj w rozmowie. |
| **Cap** | Loom | Nagrywaj ekran i udostępniaj wideo. Idealny do tutoriali i komunikacji asynchronicznej. |
| **Umami** | Google Analytics | Statystyki WWW. Proste, czytelne, szanujące prywatność (bez RODO-paniki). |
| **Cookie Hub** | Cookiebot / CookieYes | Centralny serwer zgód RODO (Klaro!). Zarządzaj ciasteczkami na wszystkich stronach z jednego miejsca. |
| **FileBrowser** | Tiiny.host / Dropbox | Prywatny Google Drive + Hosting (Tiiny.host Killer). Wrzucaj PDF-y i Landing Page przez WWW. |

### 🏢 Biuro & Produktywność
| Narzędzie | Zastępuje | Opis |
| :--- | :--- | :--- |
| **NocoDB** | Airtable | Twoja baza danych jako Arkusz Kalkulacyjny. Trzymaj tu dane klientów, zamówienia, projekty. |
| **Stirling-PDF** | Adobe Acrobat Pro | Edytuj, łącz, dziel i podpisuj PDF-y w przeglądarce. Bez wysyłania plików w świat. |
| **Vaultwarden** | 1Password / LastPass | Bezpieczny sejf na hasła dla całej firmy. |
| **LinkStack** | Linktree | Twoja wizytówka "Link in Bio" z panelem admina. |
| **LittleLink** | Linktree | Wizytówka "Link in Bio" – wersja ultra-lekka (czysty HTML). |

---

## 🔗 Ekosystem: Jak to połączyć w maszynę?

Te narzędzia nie są samotnymi wyspami. Razem tworzą **System Operacyjny Firmy**.

### Scenariusz: "Automatyczna Sprzedaż E-booka"
1.  **Typebot:** Klient wchodzi na stronę i rozmawia z botem, który bada jego potrzeby.
2.  **GateFlow:** Bot kieruje klienta do płatności (Stripe) za e-booka.
3.  **n8n:** Wykrywa nową płatność (Webhook ze Stripe).
    *   Dodaje klienta do **NocoDB** (CRM).
    *   Wysyła e-booka mailem.
    *   Wystawia fakturę (przez API Fakturowni).
    *   Dodaje klienta do **Listmonk** (Newsletter).
4.  **Umami:** Śledzi konwersję na każdym etapie.

Wszystko dzieje się automatycznie, na Twoim serwerze, bez miesięcznych opłat.

---

## 🚀 Instrukcja Startu (Krok po kroku)

### Wymagania
1.  **Serwer VPS:** Np. Mikrus 3.0 lub 4.0.
2.  **Konto GitHub:** Do pobierania skryptów.
3.  **Domena:** Np. `mojafirma.pl` podpięta pod Cloudflare (zalecane) lub bezpośrednio na IP serwera.

### Krok 0: Przygotowanie (Na Twoim komputerze)
Musisz mieć skonfigurowany dostęp SSH do serwera (alias `mikrus`).
```bash
# Uruchom ten skrypt, aby skonfigurować dostęp w 30 sekund:
curl -s https://raw.githubusercontent.com/pavvel11/mikrus-n8n-manager/main/setup_mikrus.sh | bash
```
Upewnij się też, że masz zainstalowanego **Gita** i **Rclone** (do backupów).

### Krok 1: Pobierz Toolbox (Na Twoim komputerze)
```bash
git clone https://github.com/TwojUser/mikrus-toolbox.git
cd mikrus-toolbox
```

### Krok 2: Instalacja Fundamentów (Na Serwerze)
Użyjemy naszego magicznego skryptu `local/deploy.sh`, który wysyła instrukcje na serwer.

1.  **Docker & Optymalizacja:** (Zapobiega zapchaniu dysku logami)
    ```bash
    ./local/deploy.sh system/docker-setup.sh
    ```
2.  **Caddy Server:** (Daje automatyczne kłódki SSL - HTTPS)
    ```bash
    ./local/deploy.sh system/caddy-install.sh
    ```

### Krok 3: Instalacja Aplikacji (Przykłady)
Każda aplikacja zapyta Cię o niezbędne dane (Domenę, Hasła do bazy).

**Instalacja n8n:**
```bash
./local/deploy.sh apps/n8n.sh
```
*Tip: Skrypt zapyta o dane do bazy Postgres. Użyj zewnętrznej bazy (np. Mikrusowej lub ElephantSQL), żeby oszczędzać RAM!*

**Instalacja Panelu Sterowania (Dockge):**
```bash
./local/deploy.sh apps/dockge.sh
```

**Instalacja Newslettera (Listmonk):**
```bash
./local/deploy.sh apps/listmonk.sh
```

### Krok 4: Bezpieczeństwo (Backup) - OBOWIĄZKOWE!
Nie pozwól, żeby awaria zniszczyła Twój biznes. Skonfiguruj szyfrowany backup do Google Drive.

1.  Uruchom kreator na swoim Macu:
    ```bash
    ./local/setup-backup.sh
    ```
2.  Wybierz "Google Drive". Zaloguj się w przeglądarce.
3.  Zaznacz "YES" przy szyfrowaniu.
4.  Gotowe! Twój serwer co noc wysyła zaszyfrowane dane w bezpieczne miejsce.

---

## ⚡ Power User Zone (Dla Zaawansowanych)

### 🛠️ Power Tools (`system/power-tools.sh`)
Zainstaluj zestaw potężnych narzędzi CLI na serwerze: `yt-dlp` (pobieranie wideo), `ffmpeg` (konwersja), `pup` (HTML parsing).

```bash
./local/deploy.sh system/power-tools.sh
```

**Jak użyć tego w n8n?**
n8n działa w kontenerze, a te narzędzia są na serwerze (hoście).
1.  W n8n użyj węzła **"Execute Command"**.
2.  Jako komendę wpisz: `ssh user@172.17.0.1 "yt-dlp https://youtube.com/..."` (połącz się z kontenera do hosta).
3.  *Tip:* Możesz zapytać AI (Claude/Gemini) o inne przydatne paczki apt i zainstalować je ręcznie przez SSH.

### 📦 Pełny Backup n8n (`apps/n8n-export.sh`)
Zwykły backup plików to za mało. Ten skrypt eksportuje Twoje workflowy do JSON i szyfruje credentiale.
```bash
./local/deploy.sh apps/n8n-export.sh
```
Uruchamiaj go przed każdą dużą zmianą lub dodaj do Crona.

---

## 💡 Przydatne Komendy

### Synchronizacja Plików (Mac <-> Mikrus)
Chcesz wrzucić pliki strony na serwer? Albo pobrać logi?
```bash
# Wyślij na serwer (UP)
./local/sync.sh up ./moja-strona /var/www/moja-strona

# Pobierz z serwera (DOWN)
./local/sync.sh down /opt/stacks/n8n/docker-compose.yaml ./n8n-backup/
```

### Ratunek (Emergency Restore)
Coś wybuchło? Przywróć serwer do stanu z wczoraj.
```bash
./local/restore.sh
```

### Dodawanie domen (HTTPS)
Postawiłeś coś na porcie 5000 i chcesz mieć ładną domenę?
Zaloguj się na serwer (`ssh mikrus`) i wpisz:
```bash
mikrus-expose mojadomena.pl 5000
```
Caddy zrobi resztę (Certyfikat, Config, Reload).

---

## ❓ FAQ

**Q: Czy to jest bezpieczne?**
A: Tak.
- Wszystkie usługi są za firewallem lub w kontenerach.
- Dostęp z zewnątrz tylko przez HTTPS (Caddy).
- Masz szyfrowane backupy off-site (poza serwerem).

**Q: Ile RAMu potrzebuję?**
A:
- Podstawa (Caddy + Dockge): ~100MB
- n8n (z zewnętrzną bazą): ~300-400MB
- Typebot: ~300MB
- Listmonk: ~50MB
*Rekomendacja:* Mikrus 3.0 (1GB RAM) uciągnie n8n + 2-3 mniejsze usługi. Do pełnego zestawu (n8n + Typebot + GateFlow) zalecany Mikrus 4.0 (2GB RAM).

**Q: Co z bazą danych?**
A: Większość skryptów (n8n, Umami, Listmonk) poprosi o dane do Postgresa. **NIE INSTALUJ POSTGRESA NA MIKRUSIE 3.0.** Kup "Cegłę" bazy danych na Mikrusie (29 zł/rok) lub użyj darmowego tieru w chmurze (Neon, Supabase). To oszczędza mnóstwo zasobów.

---
**Twórca:** Paweł (Lazy Engineer)
*Automatyzuj mądrze.*