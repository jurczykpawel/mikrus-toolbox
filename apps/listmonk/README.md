# 📧 Listmonk - Twój system newsletterowy

Listmonk to lekki i potężny system do wysyłania newsletterów. Zapomnij o limitach subskrybentów w Mailchimp.

## 🚀 Jak zacząć?

1. **Baza danych:** Listmonk wymaga PostgreSQL. Użyj współdzielonej bazy Mikrusa (tak jak w n8n).
2. **Instalacja:**
   ```bash
   ./local/deploy.sh listmonk
   ```
3. **Konfiguracja SMTP:** Po wejściu do panelu musisz podać dane serwera SMTP (np. Amazon SES, Mailgun lub własny serwer pocztowy), przez który będą wychodzić maile.

## 💡 Dlaczego Kamil go kocha?
- **Zero opłat za bazę:** Masz 10 000 subskrybentów? Płacisz tyle samo, co za 10.
- **Wydajność:** Napisany w Go, zajmuje ułamek RAM-u Mikrusa.
- **Integracja z n8n:** Możesz automatycznie dodawać osoby do Listmonka po zakupie w GateFlow lub rozmowie w Typebocie.