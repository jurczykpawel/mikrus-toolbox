#!/bin/bash

# Mikrus Toolbox - LittleLink (Native Caddy Version)
# No Docker. Pure static file serving via Caddy.
# Ultra fast & zero overhead.
# Author: Paweł (Lazy Engineer)

set -e

echo "--- 🔗 LittleLink Setup (Static / No-Docker) ---"

# 1. Prerequisites
if ! command -v caddy &> /dev/null; then
    echo "❌ Caddy is not installed. Run system/caddy-install.sh first."
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo apt update && sudo apt install -y git
fi

read -p "Domain (e.g., bio.kamil.pl): " DOMAIN

WEB_ROOT="/var/www/$DOMAIN"

# 2. Download LittleLink
echo "Downloading LittleLink to $WEB_ROOT..."
sudo mkdir -p "$WEB_ROOT"
# Clone only depth 1 to save space, straight into the folder
if [ -d "$WEB_ROOT/.git" ]; then
    echo "⚠️  Directory already exists. Skipping download."
else
    sudo git clone --depth 1 https://github.com/sethcottle/littlelink.git "$WEB_ROOT"
    # Remove git history to save space
    sudo rm -rf "$WEB_ROOT/.git"
fi

# 3. Configure Caddy
CADDYFILE="/etc/caddy/Caddyfile"
echo "Configuring Caddy..."

# Check if domain exists
if grep -q "$DOMAIN" "$CADDYFILE"; then
    echo "⚠️  Domain entry likely exists in Caddyfile. Please verify manually."
else
    # Append Static File Server block
    cat <<CONFIG | sudo tee -a "$CADDYFILE"

$DOMAIN {
    root * $WEB_ROOT
    file_server
}
CONFIG
    
    sudo systemctl reload caddy
    echo "✅ Caddy reloaded."
fi

echo ""
echo "✅ LittleLink is live at https://$DOMAIN"
echo "📂 Files are located at: $WEB_ROOT"
echo ""
echo "👉 How to edit:"
echo "   Use './local/sync.sh down $WEB_ROOT ./my-bio' to download to Mac."
echo "   Edit index.html."
echo "   Use './local/sync.sh up ./my-bio/ $WEB_ROOT/' to upload changes."