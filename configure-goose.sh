#!/bin/bash
# Script to configure goose non-interactively in Docker container
# This script should be run once to set up goose provider configuration

set -euo pipefail

# Name or ID of the running agent container to configure.
CONTAINER="${CONTAINER:-agent}"

echo "🦆 Configuring goose provider..."

# Run goose configure with input provided via script command
# This simulates an interactive terminal
docker exec -e COLUMNS=80 -e LINES=24 -e TERM=xterm \
  "$CONTAINER" \
  bash -c '
    (
      sleep 1
      echo "2"           # Select "Configure Providers"
      sleep 1
      echo "custom"      # Select custom provider
      sleep 1
      echo "mistral-small-latest"  # Set model
      sleep 1
      echo ""          # Accept defaults
      sleep 1
      echo ""          # Exit configure menu
    ) | script -q -f -c "timeout 15 goose configure" /tmp/goose-config-output.txt 2>&1
    pkill -9 -f "script.*goose" 2>/dev/null || true
  '

echo "✅ Goose configuration attempt completed"
echo ""
echo "Checking goose configuration..."

docker exec "$CONTAINER" timeout 5 goose doctor 2>&1 || echo "Goose doctor check failed (may still need configuration)"

echo ""
echo "📋 Configuration files created:"
docker exec "$CONTAINER" ls -la /home/appuser/.config/goose/

echo ""
echo "📄 Current config.yaml contents:"
docker exec "$CONTAINER" cat /home/appuser/.config/goose/config.yaml

echo ""
echo "✅ Goose configuration script completed!"
echo ""
echo "If goose still asks for configuration, you may need to:"
echo "1. Run this script again"
echo "2. Or manually run: docker exec -it $CONTAINER goose configure"
echo "3. Then select: Configure Providers → custom → mistral-small-latest"