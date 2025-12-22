#!/bin/bash

# Mikrus Toolbox - Cookie Hub (Klaro!)
# Centralized Cookie Consent Manager for all your domains.
# Uses NPM to fetch Klaro, Caddy to serve it.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="cookie-hub"
STACK_DIR="/var/www/$APP_NAME"

echo "--- 🍪 Cookie Hub Setup (Klaro!) ---"
echo "This will create a central server for your Cookie Consent scripts."

# 1. Prerequisites
if ! command -v npm &> /dev/null; then
    echo "❌ NPM not found. Running system/pm2-setup.sh first..."
    bash "$(dirname "$0")/../../system/pm2-setup.sh"
fi

if ! command -v caddy &> /dev/null; then
    echo "❌ Caddy not found. Please install it first."
    exit 1
fi

read -p "Domain for Cookie Hub (e.g., assets.kamil.pl): " DOMAIN

# 2. Prepare Directory
sudo mkdir -p "$STACK_DIR"
sudo chown $USER:$USER "$STACK_DIR"
cd "$STACK_DIR"

# 3. Install Klaro via NPM
echo "📦 Installing Klaro via NPM..."
if [ ! -f "package.json" ]; then
    npm init -y > /dev/null
fi
npm install klaro

# 4. Setup Public Folder
mkdir -p public
# Copy dist files to public to be served
cp node_modules/klaro/dist/klaro.js public/
cp node_modules/klaro/dist/klaro.css public/

# 5. Create Configuration Template (WITH FULL POLISH TRANSLATION)
echo "📝 Generating default config.js..."
cat <<EOF > public/config.js
// Klaro Configuration - Centralized
// Edit this file to add/remove services across ALL your sites.

var klaroConfig = {
    elementID: 'klaro',
    storageMethod: 'cookie',
    cookieName: 'mikrus_consent',
    cookieExpiresAfterDays: 365,
    default: false,
    mustConsent: false,
    acceptAll: true,
    hideDeclineAll: false,
    hideLearnMore: false,
    lang: 'pl', 

    // Translations
    translations: {
        pl: {
            consentModal: {
                title: 'Szanujemy Twoją prywatność',
                description: 'Używamy plików cookie i innych technologii, aby zapewnić najlepszą jakość korzystania z naszej strony.',
                privacyPolicy: {
                    name: 'polityką prywatności',
                    text: 'Szczegóły znajdziesz w naszej {privacyPolicy}.'
                }
            },
            consentNotice: {
                changeDescription: 'Zmieniły się zasady przetwarzania danych od Twojej ostatniej wizyty.',
                description: 'Używamy plików cookie do analizy ruchu i personalizacji treści.',
                learnMore: 'Dostosuj zgody'
            },
            purposes: {
                analytics: 'Analityka',
                security: 'Bezpieczeństwo',
                marketing: 'Marketing',
                styling: 'Stylizacja'
            },
            ok: 'Zaakceptuj wszystko',
            save: 'Zapisz wybrane',
            decline: 'Odrzuć',
            close: 'Zamknij',
            app: {
                optOut: {
                    title: '(Opcjonalne)',
                    description: 'Ta aplikacja jest domyślnie wyłączona.'
                },
                required: {
                    title: '(Wymagane)',
                    description: 'Ta aplikacja jest zawsze wymagana.'
                },
                purposes: 'Cele',
                purpose: 'Cel'
            },
            poweredBy: 'Zasilane przez Klaro!'
        }
    },

    // Services
    services: [
        {
            name: 'googleAnalytics',
            default: true,
            title: 'Google Analytics / Umami',
            purposes: ['analytics'],
            cookies: [
                [/^_ga/],
                [/^_gid/],
                [/^umami/]
            ],
            // If you use GTM or GA via script tag, add 'data-name="googleAnalytics"' to it
        }
    ]
};
EOF

# 6. Configure Caddy
CADDYFILE="/etc/caddy/Caddyfile"

if grep -q "$DOMAIN" "$CADDYFILE"; then
    echo "⚠️  Domain $DOMAIN already in Caddyfile."
else
    echo "🚀 Configuring Caddy..."
    cat <<CONFIG | sudo tee -a "$CADDYFILE"

$DOMAIN {
    root * $STACK_DIR/public
    file_server
    header Access-Control-Allow-Origin "*"
}
CONFIG
    sudo systemctl reload caddy
fi

echo ""
echo "✅ Cookie Hub is ready at https://$DOMAIN"
echo ""
echo "👉 HOW TO USE:"
echo "Paste this code into <head> of EVERY website you own:"
echo ""
echo "<link rel=\"stylesheet\" href=\"https://$DOMAIN/klaro.css\" />"
echo "<script defer type=\"text/javascript\" src=\"https://$DOMAIN/config.js\"></script>"
echo "<script defer type=\"text/javascript\" src=\"https://$DOMAIN/klaro.js\"></script>"
echo ""
echo "To edit services, just edit $STACK_DIR/public/config.js on the server."