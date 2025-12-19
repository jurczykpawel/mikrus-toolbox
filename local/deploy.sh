#!/bin/bash

# Mikrus Toolbox - Remote Deployer
# Usage: ./local/deploy.sh <script_path_relative_to_repo_root>
# Example: ./local/deploy.sh system/docker-setup.sh

TARGET="mikrus" # Assumes you have 'ssh mikrus' configured via setup_mikrus.sh
SCRIPT_PATH="$1"

# 1. Validate input
if [ -z "$SCRIPT_PATH" ]; then
  echo "❌ Error: No script or app name specified."
  echo "Usage: $0 <app_name> OR <path/to/script.sh>"
  echo "Example: $0 n8n"
  echo "Example: $0 apps/n8n/backup.sh"
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Check if it's a short app name (Smart Mode)
if [ -f "$REPO_ROOT/apps/$SCRIPT_PATH/install.sh" ]; then
    echo "💡 Detected App Name: '$SCRIPT_PATH'. Using installer."
    SCRIPT_PATH="$REPO_ROOT/apps/$SCRIPT_PATH/install.sh"
elif [ -f "$SCRIPT_PATH" ]; then
    # Direct file exists
    :
elif [ -f "$REPO_ROOT/$SCRIPT_PATH" ]; then
    # Relative to root exists
    SCRIPT_PATH="$REPO_ROOT/$SCRIPT_PATH"
else
    echo "❌ Error: Script or App '$SCRIPT_PATH' not found."
    echo "   Searched for:"
    echo "   - apps/$SCRIPT_PATH/install.sh"
    echo "   - $SCRIPT_PATH"
    exit 1
fi

# 2. Confirm action
echo "🚀 Deploying '$SCRIPT_PATH' to remote '$TARGET'..."
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# 3. Execute remotely via SSH pipe
# Using 'bash -s' allows passing arguments if we ever need them
cat "$SCRIPT_PATH" | ssh "$TARGET" "bash -s"

echo "✅ Deployment finished."
