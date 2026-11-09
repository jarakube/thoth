#!/usr/bin/env bash

set -euo pipefail

# Set default value for positional parameters to avoid unbound variable errors
if [ $# -eq 0 ]; then
  set -- "bash" "-c" "while true; do sleep 3600; done"
fi

metrics_enabled="${OPENCODE_METRICS_ENABLED:-1}"
metrics_host="${OPENCODE_METRICS_HOST:-0.0.0.0}"
metrics_port="${OPENCODE_METRICS_PORT:-9464}"
metrics_dir="${OPENCODE_RUN_METRICS_DIR:-/app/share/opencode-runs}"

# Map opencode configuration to goose at startup
if [ -f "/home/appuser/.config/goose/setup-goose-env.sh" ]; then
  source /home/appuser/.config/goose/setup-goose-env.sh
fi

# Auto-detect if we should use goose-opencode wrapper
if [ -f "/usr/local/bin/goose-opencode" ] && [ "$1" = "opencode" ]; then
  echo "🔄 Mapping opencode configuration to goose..."
  set -- goose-opencode "${@:2}"
fi

# Optional: relocate goosetown working directories to a mounted volume.
# Set GOOSETOWN_DATA_DIR (e.g. to a persistent PVC mount) before starting
# the container; GUIDES, PLANS, RESEARCH and WORK_LOGS will live under
# ${GOOSETOWN_DATA_DIR}/goosetown/ instead of the ephemeral container fs.
if [ -n "${GOOSETOWN_DATA_DIR:-}" ]; then
  export GOOSETOWN_DIR="${GOOSETOWN_DATA_DIR}/goosetown"
  export GUIDES_DIR="${GOOSETOWN_DIR}/GUIDES"
  export PLANS_DIR="${GOOSETOWN_DIR}/PLANS"
  export RESEARCH_DIR="${GOOSETOWN_DIR}/RESEARCH"
  export WORK_LOGS_DIR="${GOOSETOWN_DIR}/WORK_LOGS"
fi

# Use goose wrapper script from goosetown directory to enable telepathy and wall
# This sets up orchestrator -> delegate communication
if [ "$1" = "goose" ]; then
  GOOSE_WRAPPER="/app/goosetown/goose"
  if [ -f "$GOOSE_WRAPPER" ]; then
    echo "🦆 goosetown telepathy enabled - using goose wrapper..."
    set -- "$GOOSE_WRAPPER" "${@:2}"
  fi
fi

if [[ "$metrics_enabled" != "0" ]]; then
  python3 /app/scripts/opencode-prometheus-exporter.py \
    --host "$metrics_host" \
    --port "$metrics_port" \
    --metrics-dir "$metrics_dir" &
fi

# Add Goosetown aliases to bashrc for persistence
if [ -f "/home/appuser/.bashrc" ] && ! grep -q "goosetown" /home/appuser/.bashrc 2>/dev/null; then
  echo '' >> /home/appuser/.bashrc
  echo '# Goosetown alias - automatically loads goosetown orchestrator' >> /home/appuser/.bashrc
  echo 'alias goosetown="goose load source:goosetown-orchestrator"' >> /home/appuser/.bashrc
  echo 'alias gt="goose load source:goosetown-orchestrator"' >> /home/appuser/.bashrc
fi

# Source bashrc to set variables in current shell
if [ -f "/home/appuser/.bashrc" ]; then
  source /home/appuser/.bashrc
fi

exec "$@"
