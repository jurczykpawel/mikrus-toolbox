# 🐳 Dockge - Panel Sterowania Kontenerami

Dockge to ultralekki interfejs do zarządzania Docker Compose. Zastępuje ciężkiego Portainera.

## 🚀 Instalacja

```bash
./local/deploy.sh dockge
```

## 💡 Dlaczego Kamil go kocha?
- **Zjada mało RAM-u:** W przeciwieństwie do Portainera, który potrafi zjeść 200MB+, Dockge bierze tyle co nic.
- **Pliki > Baza danych:** Dockge nie chowa Twoich konfiguracji w wewnętrznej bazie danych. Zarządza bezpośrednio plikami `compose.yaml` w katalogu `/opt/stacks`. Dzięki temu możesz edytować je zarówno w przeglądarce, jak i przez terminal/VS Code, i nic się nie rozjedzie.
- **Agent:** Możesz podpiąć inne serwery Mikrusa do jednego panelu.

## 🛠️ Jak używać?
Po instalacji wejdź na `http://twoj-ip:5001`.
Kliknij "+ Compose", wpisz nazwę (np. `wordpress`) i wklej konfigurację. To tyle.