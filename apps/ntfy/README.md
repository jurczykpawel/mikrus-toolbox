# 🔔 ntfy - Twoje Centrum Powiadomień

Serwer do wysyłania powiadomień PUSH na telefon i desktop. Zastępuje płatne Pushover.

## 🚀 Instalacja

```bash
./local/deploy.sh ntfy
```

## 💡 Jak to działa?
1. Instalujesz aplikację ntfy na telefonie (Android/iOS).
2. Subskrybujesz swój temat, np. `moj-tajny-temat`.
3. W n8n używasz noda HTTP Request, żeby wysłać POST na Twój serwer ntfy.
4. **BUM!** Masz powiadomienie na telefonie: "Nowe zamówienie w Sellf: 97 PLN".

## 🌐 Po instalacji - konfiguracja domeny

### 1. Skonfiguruj DNS
Dodaj rekord A w panelu swojego rejestratora domen (np. OVH, Cloudflare, home.pl):
- **Typ:** `A`
- **Nazwa:** `notify` (lub inna subdomena, np. `ntfy`, `push`)
- **Wartość:** IP Twojego serwera Mikrus (znajdziesz w panelu mikr.us)
- **TTL:** 3600 (lub "Auto")

> ⏳ Propagacja DNS może zająć od kilku minut do 24h. Sprawdź: `ping notify.twojadomena.pl`

### 2. Wystaw aplikację przez HTTPS
Uruchom **na swoim komputerze** (nie na serwerze!):
```bash
ssh mikrus 'mikrus-expose notify.twojadomena.pl 8085'
```
Zamień `mikrus` na swój alias SSH jeśli używasz innego, oraz `notify.twojadomena.pl` na swoją domenę.

### 3. Zaktualizuj NTFY_BASE_URL
ntfy musi znać swoją publiczną domenę. Uruchom **lokalnie**:
```bash
ssh mikrus "sed -i 's|notify.example.com|notify.twojadomena.pl|' /opt/stacks/ntfy/docker-compose.yaml && cd /opt/stacks/ntfy && docker compose up -d"
```

### 4. Utwórz użytkownika admin
ntfy ma własny system użytkowników (niezwiązany z systemem Linux). Uruchom **lokalnie**:
```bash
ssh mikrus 'docker exec -it ntfy-ntfy-1 ntfy user add --role=admin mojuser'
```
Komenda zapyta o hasło. Ten user służy do logowania w interfejsie webowym ntfy.

## 🔒 Bezpieczeństwo
Skrypt domyślnie ustawia tryb "deny-all" (nikt nie może czytać/pisać bez hasła). Dlatego krok 4 (utworzenie użytkownika) jest obowiązkowy.