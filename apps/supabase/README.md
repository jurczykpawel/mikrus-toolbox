# 🔥 Supabase Self-Hosted

Open-source alternatywa dla Firebase: PostgreSQL, Auth, Storage, Realtime, Edge Functions i Studio — na Twoim serwerze.

## 🚀 Instalacja

```bash
./local/deploy.sh supabase --ssh=mikrus --domain=supabase.example.com
```

**Wymagania:**
- ⚠️ **Minimum 2GB RAM (Mikrus 3.0+), zalecane 3GB+**
- Supabase uruchamia ~10 kontenerów Docker (~3-4GB obrazów)
- Minimum 3GB wolnego miejsca na dysku

## 💡 Co to jest Supabase?

Supabase to kompletna platforma backendowa "as-a-service":

| Usługa | Opis |
|--------|------|
| **PostgreSQL** | Baza danych z Row Level Security |
| **Auth** | Magic links, OAuth, JWT tokens |
| **PostgREST** | Auto-generowane REST API z bazy |
| **Realtime** | WebSocket subscriptions na zmiany w DB |
| **Storage** | Przechowywanie plików (S3-compatible) |
| **Edge Functions** | Serverless functions (Deno) |
| **Studio** | Panel administracyjny |

## 📌 Po instalacji

1. Otwórz Studio: `http://localhost:8000` (lub Twoja domena)
2. Zaloguj się: `supabase` / `<hasło z instalacji>`
3. Skonfiguruj SMTP w `/opt/stacks/supabase/.env`
4. Zrestartuj: `cd /opt/stacks/supabase && sudo docker compose restart`

## ⚙️ Opcje instalacji

```bash
# Z domeną (zalecane dla produkcji)
./local/deploy.sh supabase --ssh=mikrus --domain=db.example.com

# Z automatyczną domeną Cytrus
./local/deploy.sh supabase --ssh=mikrus --domain-type=cytrus --domain=auto

# Tylko lokalnie (dostęp przez SSH tunnel)
./local/deploy.sh supabase --ssh=mikrus --domain-type=local --yes
```

## 🔌 Używanie w aplikacjach

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://db.example.com',   // SUPABASE_URL
  'eyJ...'                     // ANON_KEY (z konfiguracji)
)
```

## 📧 Konfiguracja SMTP (wymagana dla produkcji)

Edytuj `/opt/stacks/supabase/.env`:

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=noreply@example.com
SMTP_PASS=your-smtp-password
SMTP_SENDER_NAME=YourApp
ENABLE_EMAIL_AUTOCONFIRM=false
```

Następnie: `cd /opt/stacks/supabase && sudo docker compose restart auth`

## 🔧 Zarządzanie

```bash
cd /opt/stacks/supabase

sudo docker compose ps              # status kontenerów
sudo docker compose logs -f         # logi wszystkich serwisów
sudo docker compose logs -f db      # logi PostgreSQL
sudo docker compose logs -f auth    # logi Auth (GoTrue)
sudo docker compose restart         # restart
sudo docker compose down            # zatrzymaj
sudo docker compose up -d           # uruchom ponownie
```

## 💾 Dane i backupy

Dane PostgreSQL przechowywane są w wolumenie Docker `supabase_db-config`.

Lokalizacja konfiguracji zapisanej przez instalator:
```
~/.config/supabase/deploy-config.env
```

## 📊 Zasoby RAM (przybliżone)

| Kontener | RAM |
|----------|-----|
| db (PostgreSQL) | ~256MB |
| kong (API gateway) | ~256MB |
| analytics (Logflare) | ~512MB |
| studio (Next.js) | ~512MB |
| auth, rest, realtime, storage, meta | ~50-128MB każdy |
| **Łącznie** | **~1.8-2.5GB** |
