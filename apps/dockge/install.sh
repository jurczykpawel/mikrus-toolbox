#!/bin/bash

# Mikrus Toolbox - Dockge Installation
# A lightweight Docker Compose manager (Perfect for Mikrus)
# Author: Paweł (Lazy Engineer)

set -e

# Configuration
DOCKGE_DIR="/opt/dockge"
STACKS_DIR="/opt/stacks"
PORT=5001

echo "--- 1. Checking Prerequisites ---"
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Running system/docker-setup.sh first..."
    # We assume the user has the toolbox repo or we just run the setup
    curl -s https://raw.githubusercontent.com/unkn0w/noobs/main/scripts/chce_dockera.sh | bash
fi

echo "--- 2. Creating Directories ---"
sudo mkdir -p "$DOCKGE_DIR" "$STACKS_DIR"
cd "$DOCKGE_DIR"

echo "--- 3. Downloading Dockge Compose File ---"
# We create it manually to ensure it's optimized
cat <<EOF | sudo tee docker-compose.yaml
version: "3.8"
services:
  dockge:
    image: louislam/dockge:1
    restart: always
    ports:
      - "$PORT:5001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - $STACKS_DIR:$STACKS_DIR
    environment:
      # Tell Dockge where the stacks are located
      - DOCKGE_STACKS_DIR=$STACKS_DIR
EOF

echo "--- 4. Starting Dockge ---"
sudo docker compose up -d

echo "✅ Dockge is running!"
echo "🔗 Access it at: http://your-mikrus-ip:$PORT"
echo "📂 Your stacks will be stored in: $STACKS_DIR"
