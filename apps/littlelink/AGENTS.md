# LittleLink - Instrukcja edycji index.html

## Lokalizacja

- Serwer: Mikrus VPS (ssh mikrus)
- Ścieżka: `/var/www/littlelink/`
- Domena: `links.techskills.academy`
- Właściciel: Paweł Jurczyk (@jurczykpawel)

## Struktura plików

```
/var/www/littlelink/
├── index.html          ← EDYTUJ TEN PLIK
├── css/
│   ├── reset.css       (nie ruszaj)
│   ├── style.css       (nie ruszaj)
│   └── brands.css      (nie ruszaj - style przycisków)
├── images/
│   ├── avatar.png      ← zdjęcie profilowe (zamień na własne)
│   ├── avatar@2x.png   ← wersja retina
│   └── icons/          ← ikony SVG (100+ brandów)
└── privacy.html
```

## Jak edytować index.html

### Szablon strony

```html
<!DOCTYPE html>
<html class="theme-dark" lang="pl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Paweł Jurczyk | TechSkills.academy</title>
    <link rel="icon" type="image/x-icon" href="/images/avatar.png">
    <meta name="description" content="Opis strony (150-160 znaków)">
    <meta name="author" content="Paweł Jurczyk">
    <link rel="stylesheet" href="css/reset.css">
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="css/brands.css">
</head>
<body>
    <div class="container">
        <div class="column">

            <img class="avatar avatar--rounded" src="images/avatar.png"
                 srcset="images/avatar@2x.png 2x" alt="Paweł Jurczyk">

            <h1><div>Imię Nazwisko</div></h1>
            <p>Krótki opis / tagline</p>

            <div class="button-stack" role="navigation">
                <!-- Tutaj dodawaj przyciski -->
            </div>

        </div>
    </div>
</body>
</html>
```

### Dodawanie przycisku

Każdy przycisk to tag `<a>` w formacie:

```html
<a class="button button-NAZWA" href="URL" target="_blank" rel="noopener" role="button">
  <img class="icon" aria-hidden="true" src="images/icons/IKONA.svg" alt="Alt text">
  Tekst przycisku
</a>
```

### Dostępne motywy (klasa na tagu html)

- `theme-dark` — ciemne tło (zalecane)
- `theme-light` — jasne tło
- `theme-auto` — automatycznie wg systemu użytkownika

### Dostępne style avatar

- `avatar--rounded` — okrągły
- `avatar--soft` — lekko zaokrąglony
- `avatar--none` — bez zaokrągleń

## Mapa: przycisk → klasa CSS → ikona

Najpopularniejsze (używaj tych):

| Serwis     | Klasa CSS           | Ikona SVG          |
|------------|---------------------|---------------------|
| YouTube    | `button-yt`         | `youtube.svg`       |
| LinkedIn   | `button-linked`     | `linkedin.svg`      |
| GitHub     | `button-github`     | `github.svg`        |
| Instagram  | `button-instagram`  | `instagram.svg`     |
| TikTok     | `button-tiktok`     | `tiktok.svg`        |
| Discord    | `button-discord`    | `discord.svg`       |
| X/Twitter  | `button-x`          | `x.svg`             |
| Reddit     | `button-reddit`     | `reddit.svg`        |
| Facebook   | `button-faceb`      | `facebook.svg`      |
| Twitch     | `button-twitch`     | `twitch.svg`        |
| Mastodon   | `button-mastodon`   | `mastodon.svg`      |
| Bluesky    | `button-bluesky`    | `bluesky.svg`       |
| Threads    | `button-threads`    | `threads.svg`       |
| Spotify    | `button-spotify`    | `spotify.svg`       |
| Medium     | `button-medium`     | `medium.svg`        |
| Substack   | `button-substack`   | `substack.svg`      |
| WordPress  | `button-wordpress`  | `wordpress.svg`     |
| Telegram   | `button-telegram`   | `telegram.svg`      |
| WhatsApp   | `button-whatsapp`   | `whatsapp.svg`      |
| Email      | `button-default`    | `generic-email.svg` |
| Website    | `button-default`    | `generic-website.svg` |

### Wszystkie dostępne klasy CSS (brands.css)

```
button-amazon, button-amazon-music, button-apple-music, button-apple-music-alt,
button-apple-podcasts, button-apple-podcasts-alt, button-appstore, button-bandcamp,
button-behance, button-bluesky, button-bluesky-alt, button-cal, button-calendly,
button-cash-app, button-coffee, button-default, button-dev-to, button-discogs,
button-discogs-alt, button-discord, button-dribbble, button-etsy, button-faceb,
button-figma, button-fiverr, button-flickr, button-github, button-gitlab,
button-gofundme, button-goodreads, button-google-black, button-google-scholar,
button-hashnode, button-instagram, button-invites, button-kick, button-kick-alt,
button-kickstarter, button-kit, button-ko-fi, button-last-fm, button-letterboxd,
button-line, button-linked, button-mailchimp, button-mastodon, button-matrix,
button-medium, button-meetup, button-meetup-alt, button-messenger, button-microsoft,
button-notion, button-obsidian, button-onlyfans, button-patreon, button-paypal,
button-pinterest, button-playstore, button-product-hunt, button-reddit, button-shop,
button-signal, button-signal-alt, button-slack, button-snapchat, button-soundcloud,
button-spotify, button-spotify-alt, button-square, button-stack-overflow,
button-steam, button-steam-alt, button-strava, button-substack, button-telegram,
button-threads, button-threema, button-tiktok, button-trello, button-tumb,
button-twitch, button-unsplash, button-venmo, button-vimeo, button-vsco,
button-whatsapp, button-wordpress, button-x, button-yt, button-yt-alt, button-zoom
```

### Wszystkie dostępne ikony (images/icons/)

```
amazon-music.svg, amazon.svg, apple-invites.svg, apple-music-alt.svg,
apple-music.svg, apple-podcasts-alt.svg, apple-podcasts.svg, apple.svg,
artstation.svg, bandcamp.svg, behance.svg, blog.svg, bluesky-alt.svg,
bluesky.svg, buy-me-a-coffee.svg, cal.svg, calendly.svg, cash-app-btc.svg,
cash-app-dollar.svg, cash-app-pound.svg, dev-to.svg, discogs-alt.svg,
discogs.svg, discord.svg, dribbble.svg, email-alt.svg, email.svg, etsy.svg,
facebook.svg, figma.svg, fiverr.svg, flickr.svg, generic-blog.svg,
generic-calendar.svg, generic-cloud.svg, generic-code.svg, generic-computer.svg,
generic-email-alt.svg, generic-email.svg, generic-homepage.svg, generic-map.svg,
generic-phone.svg, generic-review.svg, generic-rss.svg, generic-shopping-bag.svg,
generic-shopping-tag.svg, generic-sms.svg, generic-website.svg, github.svg,
gitlab.svg, gofundme.svg, goodreads.svg, google-drive.svg, google-play.svg,
google-podcasts.svg, google-scholar.svg, hashnode.svg, instagram.svg,
kick-alt.svg, kick.svg, kickstarter.svg, kit.svg, ko-fi.svg, last-fm.svg,
letterboxd.svg, line.svg, linkedin.svg, littlelink.svg, mailchimp.svg,
mastodon.svg, matrix.svg, medium.svg, meetup-alt.svg, meetup.svg,
messenger.svg, microsoft.svg, ngl.svg, notion.svg, obsidian.svg,
onlyfans.svg, patreon.svg, paypal.svg, pinterest.svg, product-hunt.svg,
reddit.svg, shop.svg, signal-alt.svg, signal.svg, slack.svg, snapchat.svg,
soundcloud.svg, spotify-alt.svg, spotify.svg, square.svg, stack-overflow.svg,
steam.svg, strava.svg, substack.svg, telegram.svg, threads.svg, threema.svg,
tiktok.svg, trello.svg, tumblr.svg, twitch.svg, unsplash.svg, venmo.svg,
vimeo.svg, vrchat.svg, vsco.svg, whatsapp.svg, wordpress.svg, x.svg,
youtube-alt.svg, youtube-music.svg, youtube.svg, zoom.svg
```

## Generyczne przyciski (button-default)

Dla linków bez dedykowanego brandu (np. strona www, email, blog) użyj klasy `button-default` z odpowiednią ikoną generyczną:

```
generic-website.svg, generic-homepage.svg, generic-email.svg, generic-email-alt.svg,
generic-blog.svg, generic-code.svg, generic-computer.svg, generic-phone.svg,
generic-calendar.svg, generic-cloud.svg, generic-map.svg, generic-review.svg,
generic-rss.svg, generic-shopping-bag.svg, generic-shopping-tag.svg, generic-sms.svg
```

## Uwagi

- Klasy CSS nie zawsze odpowiadają 1:1 nazwie ikony (np. LinkedIn = `button-linked`, Facebook = `button-faceb`, YouTube = `button-yt`, Tumblr = `button-tumb`)
- Nie dodawaj `brands-extended.css` (niepotrzebne, zwiększa rozmiar)
- Avatar: zamień `images/avatar.png` i `images/avatar@2x.png` na własne zdjęcie (kwadratowe, min. 128x128px, retina 256x256px)
- Po edycji pliku zmiany są natychmiastowe (statyczny HTML serwowany przez Caddy)
- Usuń domyślną stopkę "Build your own with LittleLink" (cały tag `<footer>`) — nie chcemy reklamować narzędzia na naszej stronie
