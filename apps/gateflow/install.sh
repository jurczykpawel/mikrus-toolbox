#!/bin/bash

# Mikrus Toolbox - GateFlow (Strict Alignment with AI-DEPLOYMENT.md)
# Deploys GateFlow Admin Panel on Port 3333 via PM2 using ecosystem.config.js.
# Author: Paweł (Lazy Engineer)

set -e

APP_NAME="gateflow"
INSTALL_DIR="/var/www/$APP_NAME"
PORT=${PORT:-3333} # As per AI-DEPLOYMENT.md

echo "--- 🚀 GateFlow Setup (Official PM2 Workflow) ---"

# Wymagane zmienne środowiskowe
MISSING_VARS=""
[ -z "$REPO_URL" ] && MISSING_VARS="$MISSING_VARS REPO_URL"
[ -z "$SUPABASE_URL" ] && MISSING_VARS="$MISSING_VARS SUPABASE_URL"
[ -z "$SUPABASE_ANON_KEY" ] && MISSING_VARS="$MISSING_VARS SUPABASE_ANON_KEY"
[ -z "$SUPABASE_SERVICE_KEY" ] && MISSING_VARS="$MISSING_VARS SUPABASE_SERVICE_KEY"
[ -z "$STRIPE_PK" ] && MISSING_VARS="$MISSING_VARS STRIPE_PK"
[ -z "$STRIPE_SK" ] && MISSING_VARS="$MISSING_VARS STRIPE_SK"
[ -z "$DOMAIN" ] && MISSING_VARS="$MISSING_VARS DOMAIN"

if [ -n "$MISSING_VARS" ]; then
    echo "❌ Brak wymaganych zmiennych:$MISSING_VARS"
    echo ""
    echo "   Użycie:"
    echo "   REPO_URL=https://github.com/... \\"
    echo "   SUPABASE_URL=https://xxx.supabase.co \\"
    echo "   SUPABASE_ANON_KEY=eyJ... \\"
    echo "   SUPABASE_SERVICE_KEY=eyJ... \\"
    echo "   STRIPE_PK=pk_live_... \\"
    echo "   STRIPE_SK=sk_live_... \\"
    echo "   DOMAIN=app.example.com ./install.sh"
    exit 1
fi

echo "✅ Repo: $REPO_URL"
echo "✅ Supabase: $SUPABASE_URL"
echo "✅ Domena: $DOMAIN"

# 1. Prerequisites Check
if ! command -v pm2 &> /dev/null; then
    echo "❌ PM2 not found. Running system/pm2-setup.sh..."
    bash "$(dirname "$0")/../system/pm2-setup.sh"
fi

# 2. Clone Repository
echo "--- 📥 Cloning Source ---"
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
# Check if .env.local exists, if not create from env vars
if [ ! -f "admin-panel/.env.local" ]; then
    cat <<ENV > admin-panel/.env.local
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_KEY
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=$STRIPE_PK
STRIPE_SECRET_KEY=$STRIPE_SK
STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET:-TODO_UPDATE_ME}
NEXT_PUBLIC_BASE_URL=https://$DOMAIN
NEXT_PUBLIC_SITE_URL=https://$DOMAIN
ENV
    echo "✅ .env.local created."
else
    echo "ℹ️  .env.local already exists. Skipping configuration."
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
