# 💰 GateFlow - System Sprzedaży Treści

GateFlow to Twój panel admina do zarządzania produktami cyfrowymi, dostępami i płatnościami.

## 🚀 Instalacja (PM2)
W przeciwieństwie do innych usług, GateFlow działa natywnie przez PM2 dla maksymalnej lekkości.

```bash
./local/deploy.sh gateflow
```

## 💸 Jak to zarabia?
GateFlow integruje się ze **Stripe**. Możesz tworzyć e-booki, kursy lub płatne newslettery.
W Toolboxie znajdziesz szablon strony lądowania (w folderze `templates` w repo GateFlow), który wystarczy podpiąć pod Caddy przez `mikrus-expose`, żeby zacząć sprzedawać w 15 minut.