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

# Goosetown: all goosetown env points at a cloned goosetown repository
# inside the workspace (host-visible via the workspace bind mount). The clone
# happens on first start; to use your own goosetown fork, place a clone at
# $GOOSETOWN_DIR (default /workspace/goosetown) or point GOOSETOWN_DIR at it.
goosetown_dir="${GOOSETOWN_DIR:-/workspace/goosetown}"
if [ ! -e "$goosetown_dir" ]; then
  goosetown_url="${GOOSETOWN_REPO_URL:-https://github.com/aaif-goose/goosetown.git}"
  clone_args=()
  if [ -n "${GOOSETOWN_REF:-}" ]; then
    clone_args+=(--branch "$GOOSETOWN_REF")
  fi
  echo "Cloning goosetown from ${goosetown_url} into ${goosetown_dir} ..."
  if git clone "${clone_args[@]+"${clone_args[@]}"}" "$goosetown_url" "$goosetown_dir"; then
    echo "goosetown cloned. Working dirs (GUIDES/PLANS/RESEARCH/WORK_LOGS) live inside it."
  else
    echo "WARNING: could not clone goosetown; goose/goosetown orchestrator may not work" >&2
  fi
fi
export GOOSETOWN_DIR="$goosetown_dir"
export GUIDES_DIR="$goosetown_dir/GUIDES"
export PLANS_DIR="$goosetown_dir/PLANS"
export RESEARCH_DIR="$goosetown_dir/RESEARCH"
export WORK_LOGS_DIR="$goosetown_dir/WORK_LOGS"

# Persist to .bashrc so interactive shells (docker compose exec) see the
# same locations; these shells do not inherit PID 1's exports.
if [ -f "/home/appuser/.bashrc" ] && ! grep -q "GOOSETOWN_DIR=" /home/appuser/.bashrc 2>/dev/null; then
  cat >> /home/appuser/.bashrc <<BASHRC_EOF

# Goosetown working repository (cloned into the workspace)
export GOOSETOWN_DIR="$goosetown_dir"
export GUIDES_DIR="$goosetown_dir/GUIDES"
export PLANS_DIR="$goosetown_dir/PLANS"
export RESEARCH_DIR="$goosetown_dir/RESEARCH"
export WORK_LOGS_DIR="$goosetown_dir/WORK_LOGS"
BASHRC_EOF
fi

# Use goose wrapper from the workspace goosetown clone (telepathy + wall);
# fall back to the copy baked into the image at /app/goosetown.
if [ "$1" = "goose" ]; then
  GOOSE_WRAPPER="${GOOSETOWN_DIR}/goose"
  if [ ! -f "$GOOSE_WRAPPER" ]; then
    GOOSE_WRAPPER="/app/goosetown/goose"
  fi
  if [ -f "$GOOSE_WRAPPER" ]; then
    echo "🦆 goosetown telepathy enabled - using $GOOSE_WRAPPER"
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
