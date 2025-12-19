#!/bin/bash

# Mikrus Toolbox - GateFlow (Strict Alignment with AI-DEPLOYMENT.md)
# Deploys GateFlow Admin Panel on Port 3333 via PM2 using ecosystem.config.js.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="gateflow"
INSTALL_DIR="/var/www/$APP_NAME"
PORT=3333 # As per AI-DEPLOYMENT.md

echo "--- 🚀 GateFlow Setup (Official PM2 Workflow) ---"

# 1. Prerequisites Check
if ! command -v pm2 &> /dev/null; then
    echo "❌ PM2 not found. Running system/pm2-setup.sh..."
    bash "$(dirname "$0")/../system/pm2-setup.sh"
fi

# 2. Clone Repository
echo "--- 📥 Cloning Source ---"
read -p "GitHub Repository URL: " REPO_URL
sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "⚠️  Directory already exists. Pulling changes..."
    cd "$INSTALL_DIR" && git pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# 3. Create ecosystem.config.js (As per AI-DEPLOYMENT.md)
echo "--- ⚙️  Generating ecosystem.config.js ---"
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "gateflow-admin",
      cwd: "./admin-panel",
      script: "npm",
      args: "start",
      env: {
        NODE_ENV: "production",
        PORT: 3333
      }
    }
  ]
};
EOF

# 4. Configure Environment
echo "--- 🔑 Configuring .env.local ---"
# Check if .env.local exists, if not ask
if [ ! -f "admin-panel/.env.local" ]; then
    read -p "Supabase URL: " SUP_URL
    read -p "Supabase Anon Key: " SUP_ANON
    read -s -p "Supabase Service Role Key: " SUP_SERVICE
    echo ""
    read -p "Stripe Publishable Key: " STRIPE_PK
    read -s -p "Stripe Secret Key: " STRIPE_SK
    echo ""
    read -p "Admin Domain (e.g., app.gateflow.pl): " DOMAIN

    cat <<ENV > admin-panel/.env.local
NEXT_PUBLIC_SUPABASE_URL=$SUP_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUP_ANON
SUPABASE_SERVICE_ROLE_KEY=$SUP_SERVICE
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=$STRIPE_PK
STRIPE_SECRET_KEY=$STRIPE_SK
STRIPE_WEBHOOK_SECRET=TODO_UPDATE_ME
NEXT_PUBLIC_BASE_URL=https://$DOMAIN
NEXT_PUBLIC_SITE_URL=https://$DOMAIN
ENV
    echo "✅ .env.local created."
else
    echo "ℹ️  .env.local already exists. Skipping configuration."
    # We still need DOMAIN for Caddy setup later
    read -p "Confirm Admin Domain (for Caddy setup): " DOMAIN
fi

# 5. Build & Install
echo "--- 🛠️  Building Application ---"
cd admin-panel
npm install
# Ensure we have required build deps
npm install --save @tailwindcss/postcss || true # Fix common webpack issue mentioned in doc
npm run build

# 6. Start via PM2
echo "--- 🚀 Starting PM2 Service ---"
cd .. # Back to root where ecosystem.config.js is
pm2 start ecosystem.config.js || pm2 restart gateflow-admin
pm2 save

# 7. Expose via Caddy
if command -v mikrus-expose &> /dev/null; then
    sudo mikrus-expose "$DOMAIN" "$PORT"
fi

echo "✅ GateFlow Deployment Complete!"
echo "   URL: https://$DOMAIN"
echo "   PM2 Name: gateflow-admin"
echo "   Logs: pm2 logs gateflow-admin"
