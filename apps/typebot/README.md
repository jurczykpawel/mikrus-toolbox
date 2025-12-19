# 🤖 Typebot - Chatboty i Formularze

Typebot to wizualny kreator chatbotów, który zastępuje drogie narzędzia typu Typeform.

## 🚀 Instalacja

```bash
./local/deploy.sh typebot
```

## 🔗 Integracja "Lazy Engineer"
Typebot to "wejście" do Twojego systemu. 
1. Klient wypełnia bota.
2. Bot wysyła dane do **n8n** przez webhooka.
3. n8n zapisuje dane w **NocoDB** i wysyła ofertę przez **Listmonka**.

## ⚠️ Uwaga o zasobach
Typebot składa się z dwóch części: Buildera (do tworzenia) i Viewera (to co widzi klient). Oba potrzebują łącznie ok. 600MB RAM, więc miej to na uwadze przy planowaniu usług na jednym Mikrusie.