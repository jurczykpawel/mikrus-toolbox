# 🔐 Vaultwarden - Sejf na hasła

Twoje hasła do wszystkich usług w jednym, bezpiecznym miejscu na Twoim serwerze.

## 🚀 Instalacja

```bash
./local/deploy.sh vaultwarden
```

## 🛡️ Ważne kroki po instalacji:
1. **Zarejestruj się natychmiast** po uruchomieniu usługi.
2. Po założeniu konta, wyłącz rejestrację dla innych, aby nikt obcy nie mógł założyć konta na Twoim serwerze. Edytuj `docker-compose.yaml` w `/opt/stacks/vaultwarden` i ustaw `SIGNUPS_ALLOWED=false`.
3. Używaj dedykowanej aplikacji mobilnej i wtyczki do przeglądarki Bitwarden – są w pełni kompatybilne.