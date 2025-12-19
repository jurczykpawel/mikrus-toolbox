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
4. **BUM!** Masz powiadomienie na telefonie: "Nowe zamówienie w GateFlow: 97 PLN".

## 🔒 Bezpieczeństwo
Skrypt domyślnie ustawia tryb "deny-all" (nikt nie może czytać/pisać bez hasła). Musisz utworzyć użytkownika przez terminal (instrukcja wyświetli się po instalacji).