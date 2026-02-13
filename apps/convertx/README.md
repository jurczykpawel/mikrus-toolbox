# ConvertX - Uniwersalny Konwerter Plików

Self-hosted konwerter plików obsługujący 1000+ formatów: obrazy, dokumenty, audio, wideo.

## Dlaczego ConvertX?

| Cecha | ConvertX | CloudConvert | Zamzar |
|-------|----------|-------------|--------|
| Cena | Darmowy (self-hosted) | Od $8/mies. | Od $18/mies. |
| Prywatność | Pliki nigdy nie opuszczają serwera | Chmura | Chmura |
| Formaty | 1000+ | 200+ | 1100+ |
| RAM | ~150MB | - | - |

## Instalacja

```bash
./local/deploy.sh convertx --ssh=hanna --domain-type=cytrus --domain=auto
```

## Wymagania

- **RAM:** ~150MB (limit kontenera: 256MB)
- **Dysk:** ~400MB (obraz Docker)
- **Baza danych:** Nie wymaga (SQLite wbudowany)

## Po instalacji

1. Otwórz stronę w przeglądarce
2. Utwórz konto administratora
3. Konwertuj pliki!

## Obsługiwane formaty (przykłady)

- **Obrazy:** PNG, JPG, WebP, SVG, AVIF, HEIC, TIFF...
- **Dokumenty:** PDF, DOCX, ODT, TXT, HTML, Markdown...
- **Audio:** MP3, WAV, FLAC, OGG, AAC...
- **Wideo:** MP4, WebM, AVI, MKV, MOV...
