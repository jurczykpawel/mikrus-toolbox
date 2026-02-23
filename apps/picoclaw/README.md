# PicoClaw - Ultra-lekki Asystent AI

Osobisty asystent AI, ktory automatyzuje zadania przez Telegram, Discord lub Slack. Alternatywa dla OpenClaw.

**RAM:** ~64MB | **Obraz:** ~10MB | **Plan:** Mikrus 2.1+ (1GB RAM)

---

## Dlaczego PicoClaw?

- **Ultra-lekki** — binarny plik ~8MB, zuzycie RAM <64MB
- **17k+ gwiazdek** na GitHubie
- **Wiele kanalow** — Telegram, Discord, Slack
- **Wiele dostawcow LLM** — OpenRouter, Anthropic, OpenAI i inne
- **Gateway mode** — bot dziala jako dlugo-zywy proces, bez potrzeby wystawiania portow

---

## Instalacja

```bash
./local/deploy.sh picoclaw --ssh=mikrus --domain-type=local
```

Skrypt przeprowadzi Cie przez:
1. Wybor dostawcy LLM (OpenRouter, Anthropic, OpenAI)
2. Podanie klucza API
3. Wybor kanalu czatu (Telegram, Discord, Slack)
4. Podanie tokenow bota

> **Uwaga:** PicoClaw nie wymaga domeny — bot komunikuje sie wylacznie polaczeniami wychodzacymi. Uzyj `--domain-type=local`.

### Tryb automatyczny

```bash
# 1. Utworz config.json recznie (patrz sekcja Konfiguracja ponizej)
# 2. Skopiuj na serwer
scp config.json mikrus:/opt/stacks/picoclaw/config/config.json

# 3. Zainstaluj automatycznie
./local/deploy.sh picoclaw --ssh=mikrus --domain-type=local --yes
```

---

## Wymagania

| Usluga | Koszt | Do czego | Obowiazkowe |
|--------|-------|----------|-------------|
| **Mikrus 2.1+** | 75 zl/rok | Hosting kontenera | Tak |
| **Klucz API LLM** | Od darmowego | Modele AI | Tak |
| **Bot token** | Darmowe | Kanal komunikacji | Tak |

### Przed instalacja:

1. **Klucz API LLM** — jeden z:
   - [OpenRouter](https://openrouter.ai/keys) (zalecany — dostep do wielu modeli, darmowe modele dostepne)
   - [Anthropic](https://console.anthropic.com/settings/keys)
   - [OpenAI](https://platform.openai.com/api-keys)

2. **Token bota** — jeden z:
   - **Telegram** (zalecany): [@BotFather](https://t.me/BotFather) → `/newbot`
   - **Discord**: [Developer Portal](https://discord.com/developers/applications) → Bot → Token
   - **Slack**: [API Apps](https://api.slack.com/apps) → Bot Token + App Token

---

## Konfiguracja

Plik konfiguracyjny: `/opt/stacks/picoclaw/config/config.json`

Format konfiguracji PicoClaw v0.1.2 sklada sie z trzech sekcji:
- **agents** — domyslny model i parametry
- **providers** — dostawcy LLM z kluczami API
- **channels** — kanaly czatu (Telegram, Discord, Slack)

### Telegram (zalecany)

```json
{
  "agents": {
    "defaults": {
      "model": "openrouter/anthropic/claude-sonnet-4-20250514"
    }
  },
  "providers": {
    "openrouter": {
      "api_key": "sk-or-v1-...",
      "api_base": "https://openrouter.ai/api/v1"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "123456789:AAH...",
      "allowed_users": [123456789]
    }
  }
}
```

**Jak zdobyc Telegram User ID:** Napisz do [@userinfobot](https://t.me/userinfobot) — odpowie Twoim numerycznym ID.

### Discord

```json
{
  "agents": {
    "defaults": {
      "model": "anthropic/claude-sonnet-4-20250514"
    }
  },
  "providers": {
    "anthropic": {
      "api_key": "sk-ant-..."
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "token": "MTIz..."
    }
  }
}
```

**Zaproszenie bota na serwer Discord:**
1. Otworz [Discord Developer Portal](https://discord.com/developers/applications)
2. Wybierz aplikacje → **Bot** → wlacz **Message Content Intent**
3. Przejdz do **OAuth2** → **URL Generator**
4. Zaznacz scopes: `bot`, `applications.commands`
5. Zaznacz permissions (Bot Permissions):

| Uprawnienie | Wymagane | Dlaczego |
|-------------|----------|----------|
| Send Messages | **Tak** | Bot musi odpowiadac |
| Read Message History | **Tak** | Bot widzi kontekst rozmowy |
| View Channels | **Tak** | Bot widzi kanaly (General Permissions) |
| Embed Links | Zalecane | Linki z podgladem w odpowiedziach |
| Attach Files | Zalecane | Jesli bot wygeneruje plik |
| Add Reactions | Zalecane | Potwierdzanie reakcjami |
| Use Slash Commands | Opcjonalne | Na przyszlosc (slash commands) |

6. Skopiuj URL na dole i otworz w przegladarce — wybierz serwer

### Slack

```json
{
  "agents": {
    "defaults": {
      "model": "openai/gpt-4o"
    }
  },
  "providers": {
    "openai": {
      "api_key": "sk-..."
    }
  },
  "channels": {
    "slack": {
      "enabled": true,
      "bot_token": "xoxb-...",
      "app_token": "xapp-..."
    }
  }
}
```

### Wybor modelu

PicoClaw to **agent z narzedziami** (tool use / function calling). Model musi wspierac tool use — nie kazdy to potrafi.

#### Modele platne (zalecane — dzialaja bez niespodzianek)

Platne modele maja pelne tool use, brak rate limitow, najlepsza jakosc. Przez OpenRouter (jedno API, jedno konto) masz dostep do wszystkich:

| Model | Koszt ~100 wiadomosci | Do czego |
|-------|----------------------|----------|
| `anthropic/claude-sonnet-4-20250514` | ~$0.30 | Najlepsza jakosc, swietny po polsku |
| `openai/gpt-4o` | ~$0.25 | Szybki, dobry ogolnie |
| `google/gemini-2.0-flash` | ~$0.03 | Ultra tani, szybki, dobra jakosc |
| `qwen/qwen3.5-397b-a17b` | ~$0.10 | Tani, 262k kontekst, multimodalny |

```json
{
  "agents": { "defaults": { "model": "google/gemini-2.0-flash" } },
  "providers": { "openrouter": { "api_key": "sk-or-...", "api_base": "https://openrouter.ai/api/v1" } }
}
```

Gemini Flash to najlepszy stosunek jakosc/cena — ~$0.03 za 100 wiadomosci, tool use, szybki.

#### Modele darmowe — OpenRouter auto-router

```json
{
  "agents": { "defaults": { "model": "openrouter/auto" } },
  "providers": { "openrouter": { "api_key": "sk-or-...", "api_base": "https://openrouter.ai/api/v1" } }
}
```

Auto-router sam wybiera najlepszy dostepny darmowy model z obsluga tool use. Konto na [openrouter.ai](https://openrouter.ai) — bez karty, za darmo. Wada: darmowe modele bywaja rate-limitowane w godzinach szczytu.

#### Modele darmowe — Groq (ultra szybki)

```json
{
  "agents": { "defaults": { "model": "groq/openai/gpt-oss-20b" } },
  "providers": { "groq": { "api_key": "gsk_...", "api_base": "https://api.groq.com/openai/v1" } }
}
```

Konto na [console.groq.com](https://console.groq.com) — bez karty, za darmo. Ultra szybkie odpowiedzi, ale ograniczone limity tokenow.

#### Darmowe modele — co dziala, co nie

PicoClaw wysyla ~3.5k tokenow per request (system prompt + 13 narzedzi). Wiele darmowych modeli nie wspiera tool use lub ma za niskie limity.

**Dzialajace darmowe modele:**

| Model | Provider | Uwagi |
|-------|----------|-------|
| `openrouter/auto` | OpenRouter | ✅ Najlatwiejszy — sam dobiera model |
| `groq/openai/gpt-oss-20b` | Groq | ✅ Szybki, dobra jakosc |
| `groq/meta-llama/llama-4-scout-17b-16e-instruct` | Groq | ✅ Szybki, slabsza jakosc |

**Modele ktore NIE dzialaja:**

| Model | Problem |
|-------|---------|
| `deepseek/deepseek-r1-*` | Brak tool use (model reasoning) |
| `nousresearch/hermes-3-llama-3.1-405b:free` | Brak tool use na darmowym tierze |
| `groq/meta-llama/llama-4-maverick-*` | Za duzy na darmowy tier Groq (wymaga 13k+ TPM, limit 6k) |
| `groq/moonshotai/kimi-k2-instruct` | Za duzy na darmowy tier Groq |
| `groq/llama-3.3-70b-versatile` | Bledny format tool calling (XML zamiast JSON) |

#### Wiele konfiguracji (szybkie przelaczanie)

Mozesz trzymac kilka configow i przelaczac jednym poleceniem:

```bash
# Przelacz na config do kodowania
ssh mikrus 'cp /opt/stacks/picoclaw/config/config-coding.json /opt/stacks/picoclaw/config/config.json && docker restart picoclaw'

# Wróc na domyslny
ssh mikrus 'cp /opt/stacks/picoclaw/config/config-default.json /opt/stacks/picoclaw/config/config.json && docker restart picoclaw'
```

---

### Tryb automatyczny (--yes)

W trybie `--yes` (bez terminala) installer tworzy template `config.json` z placeholderami:

```bash
./local/deploy.sh picoclaw --ssh=mikrus --domain-type=local --yes
# Installer utworzy /opt/stacks/picoclaw/config/config.json z UZUPELNIJ_*
# Uzupelnij plik na serwerze:
ssh mikrus 'nano /opt/stacks/picoclaw/config/config.json'
# Uruchom deploy ponownie:
./local/deploy.sh picoclaw --ssh=mikrus --domain-type=local --yes
```

---

## Bezpieczenstwo

PicoClaw to agent AI wykonujacy komendy — dlatego instalator stosuje **najostrzejsza izolacje Docker** w calym toolboxie:

| Zabezpieczenie | Co robi |
|---|---|
| **Read-only filesystem** | Kontener nie moze modyfikowac wlasnego systemu plikow |
| **cap_drop: ALL** | Usuniete WSZYSTKIE uprawnienia Linux capabilities |
| **no-new-privileges** | Blokada eskalacji uprawnien |
| **Profil seccomp** | Niestandardowa lista dozwolonych syscalli (tylko to co potrzebne) |
| **Non-root user** | Proces dziala jako UID 1000 |
| **Limity zasobow** | Max 128MB RAM, 1 CPU, 64 procesy |
| **Brak Docker socket** | Kontener NIE ma dostepu do hosta Docker |
| **Izolowana siec** | Oddzielna siec bridge, brak dostepu do innych kontenerow |
| **tmpfs noexec** | Katalog tymczasowy bez prawa wykonywania plikow |
| **allowed_user_ids** | Tylko wskazani uzytkownicy moga wydawac polecenia (Telegram) |

### Dlaczego to wazne?

PicoClaw wykonuje komendy na podstawie instrukcji z czatu. Gdyby ktos zdolal wstrzyknac prompt (prompt injection), zle zabezpieczony kontener moglby:
- Odczytac pliki hosta
- Uruchomic inne kontenery
- Wysylac dane na zewnatrz

Dzieki powyzszym zabezpieczeniom nawet udany atak prompt injection jest ograniczony do izolowanego kontenera bez uprawnien.

---

## Zarzadzanie

```bash
# Status
ssh mikrus 'docker ps | grep picoclaw'

# Logi
ssh mikrus 'docker logs picoclaw --tail 50'

# Logi na zywo
ssh mikrus 'docker logs -f picoclaw'

# Restart
ssh mikrus 'docker restart picoclaw'

# Edycja konfiguracji
ssh mikrus 'nano /opt/stacks/picoclaw/config/config.json'
ssh mikrus 'docker restart picoclaw'  # po edycji

# Zuzycie zasobow
ssh mikrus 'docker stats picoclaw --no-stream'
```

---

## Troubleshooting

### Bot nie odpowiada

1. Sprawdz logi:
   ```bash
   ssh mikrus 'docker logs picoclaw --tail 30'
   ```

2. Sprawdz czy kontener dziala:
   ```bash
   ssh mikrus 'docker ps | grep picoclaw'
   ```

3. Sprawdz config.json — czy token bota i klucz API sa poprawne:
   ```bash
   ssh mikrus 'cat /opt/stacks/picoclaw/config/config.json'
   ```

### Kontener restartuje sie w petli

Najczesciej: bledny klucz API lub token bota.

```bash
ssh mikrus 'docker logs picoclaw --tail 50'
```

Szukaj bledow typu `401 Unauthorized` lub `invalid token`.

### Health check failing

PicoClaw uzywa wewnetrznego health checka na porcie 18790. Jesli kontener jest "unhealthy":

```bash
# Sprawdz status health checka
ssh mikrus 'docker inspect --format="{{.State.Health.Status}}" picoclaw'

# Szczegoly ostatnich checkow
ssh mikrus 'docker inspect --format="{{json .State.Health}}" picoclaw | python3 -m json.tool'
```

### Za malo RAM

PicoClaw potrzebuje minimum 64MB RAM. Limit kontenera to 128MB. Sprawdz zuzycie:

```bash
ssh mikrus 'docker stats picoclaw --no-stream --format "{{.MemUsage}}"'
```

---

## Backup

PicoClaw przechowuje dane w wolumenie `picoclaw-workspace`. Konfiguracja w `/opt/stacks/picoclaw/config/config.json`.

```bash
# Backup konfiguracji
ssh mikrus 'cp /opt/stacks/picoclaw/config/config.json ~/picoclaw-config-backup.json'

# Backup danych workspace
ssh mikrus 'docker run --rm -v picoclaw_picoclaw-workspace:/data -v /tmp:/backup alpine tar czf /backup/picoclaw-workspace.tar.gz -C /data .'
scp mikrus:/tmp/picoclaw-workspace.tar.gz ./
```

---

## Integracja z n8n

PicoClaw mozesz zintegrowac z n8n jako dodatkowy kanal powiadomien:

1. **n8n wysyla zadanie do PicoClaw** — przez Telegram API (wyslij wiadomosc do bota)
2. **PicoClaw wykonuje i raportuje** — bot odpowiada wynikiem na czacie

---

> PicoClaw: https://github.com/sipeed/picoclaw
