#!/usr/bin/env bash
# sync-llm-config.sh - keep OpenCode and goose provider configuration in
# sync from a single source of truth: environment variables.
#
# Both agents need the same data to reach an LLM endpoint (URL, API key,
# model list) but serialize it differently:
#
#   OpenCode: ~/.config/opencode/opencode.json  (custom provider via
#             @ai-sdk/openai-compatible, options.baseURL + apiKey)
#   goose:    ~/.config/goose/config.yaml       (GOOSE_PROVIDER/GOOSE_MODEL
#             + provider env vars, e.g. litellm provider with
#             LITELLM_HOST / LITELLM_API_KEY)
#
# This script reads the shared env vars once and writes/merges both files,
# so there is exactly one place to configure and both agents follow.
#
# Source of truth (all optional - unset vars are skipped):
#
#   LLM_ENDPOINT        Base URL of the OpenAI-compatible endpoint,
#                       INCLUDING the /v1 path.
#                       (e.g. http://litellm-proxy:4000/v1)
#   LLM_API_KEY_ENV     Name of the env var carrying the API key
#                       (default: CUSTOM_LITELLM_API_KEY)
#   LLM_MODELS          Space- or comma-separated model IDs as served by
#                       the endpoint's GET /v1/models
#                       (default: "mistral-small-latest mistral-large-latest")
#   LLM_DEFAULT_MODEL   Default model (default: first of LLM_MODELS)
#
# API key resolution order (first hit wins):
#   1. The env var named by LLM_API_KEY_ENV (e.g. CUSTOM_LITELLM_API_KEY)
#   2. The docker compose secret file /run/secrets/llm_api_key
#      (mounted from LLM_API_KEY_FILE on the host, e.g. `pass show ...`
#       output redirected to a file)
#
# The key is never written to any config file - both configs only
# reference the env var / secret.
#
# Generated config locations:
#   ~/.config/opencode/opencode.json   (merged - existing keys preserved)
#   ~/.config/goose/config.yaml        (GOOSE_* keys set, rest preserved)
#
# Usage:
#   ./sync-llm-config.sh            # run inside the container
#   docker compose exec -T thoth ./sync-llm-config.sh

set -euo pipefail

endpoint="${LLM_ENDPOINT:-}"
key_env="${LLM_API_KEY_ENV:-CUSTOM_LITELLM_API_KEY}"
models="${LLM_MODELS:-mistral-small-latest mistral-large-latest}"
default_model="${LLM_DEFAULT_MODEL:-}"

# No endpoint configured: nothing to sync, both agents fall back to their
# own defaults.
if [ -z "$endpoint" ]; then
  echo "sync-llm-config: LLM_ENDPOINT not set - skipping (no LLM config written)"
  exit 0
fi

first_model="${default_model:-$(echo "$models" | tr ',' ' ' | awk '{print $1}')}"
model_ids=$(echo "$models" | tr ',' ' ' | xargs)

# --- API key resolution ----------------------------------------------------
# 1) env var named by LLM_API_KEY_ENV; 2) compose secret file. The key is
# exported so the {env:...} references in the generated configs resolve.
# It is never written into any file.
secret_file="/run/secrets/llm_api_key"
if [ -z "${!key_env:-}" ] && [ -s "$secret_file" ]; then
  key_value="$(head -n1 "$secret_file" | tr -d '[:space:]')"
  if [ -n "$key_value" ]; then
    export "$key_env"="$key_value"
    echo "sync-llm-config: ${key_env} loaded from secret file $secret_file"
  fi
fi

opencode_cfg="$HOME/.config/opencode/opencode.json"
goose_cfg="$HOME/.config/goose/config.yaml"

# --- OpenCode: merge custom provider into opencode.json -------------------
mkdir -p "$(dirname "$opencode_cfg")"
python3 - "$opencode_cfg" "$endpoint" "$key_env" $model_ids <<'PYEOF'
import json
import os
import sys

cfg_path, endpoint, key_env, *model_ids = sys.argv[1:]

try:
    with open(cfg_path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

provider = {
    "npm": "@ai-sdk/openai-compatible",
    "name": "LLM Proxy",
    "options": {
        "baseURL": endpoint,
        "apiKey": "{env:%s}" % key_env,
    },
    "models": {m: {"name": m} for m in model_ids},
}

cfg.setdefault("provider", {})
# preserve user customizations: only set what is absent
cfg["provider"]["litellm"] = provider

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print(f"sync-llm-config: wrote OpenCode provider 'litellm' -> {cfg_path}")
PYEOF

# default model (only if the user has not chosen one)
python3 - "$opencode_cfg" "$first_model" <<'PYEOF'
import json
import sys

cfg_path, default_model = sys.argv[1:2 + 1]
with open(cfg_path) as f:
    cfg = json.load(f)
if "model" not in cfg:
    cfg["model"] = "litellm/" + default_model
    with open(cfg_path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print(f"sync-llm-config: OpenCode default model -> litellm/{default_model}")
PYEOF

# --- goose: set GOOSE_* in config.yaml ------------------------------------
mkdir -p "$(dirname "$goose_cfg")"

# goose litellm provider wants host WITHOUT the /v1 path, and a separate
# base path (default v1/chat/completions). Split the endpoint.
host_part="${endpoint%/}"
base_path="v1/chat/completions"
case "$host_part" in
  */v1) host_part="${host_part%/v1}";;
esac

set_goose_key() {
  key="$1"; value="$2"; file="$3"
  if [ -f "$file" ] && grep -q "^${key}:" "$file"; then
    # update in place, preserving position
    sed -i "s|^${key}:.*|${key}: \"${value}\"|" "$file"
  else
    echo "${key}: \"${value}\"" >> "$file"
  fi
}

# only set the provider if the user has not configured one
if [ ! -f "$goose_cfg" ] || ! grep -q "^GOOSE_PROVIDER:" "$goose_cfg"; then
  set_goose_key "GOOSE_PROVIDER" "litellm" "$goose_cfg"
fi
set_goose_key "GOOSE_MODEL" "$first_model" "$goose_cfg"
set_goose_key "GATEWAY_ENFORCE" "false" "$goose_cfg" 2>/dev/null || true

# provider env for the litellm provider: exported for interactive shells
# via a sourced snippet, and available to goose through the environment
goose_env_file="$HOME/.config/goose/set-env.sh"
cat > "$goose_env_file" <<ENVEOF
# Generated by sync-llm-config.sh - LLM endpoint shared with OpenCode.
# Source of truth: LLM_ENDPOINT / ${key_env} environment variables.
export LITELLM_HOST="${host_part}"
export LITELLM_BASE_PATH="${base_path}"
export LITELLM_API_KEY="\${${key_env}:-}"
ENVEOF
echo "sync-llm-config: wrote goose litellm provider env -> $goose_env_file"

# Persist for interactive shells (docker compose exec): they do not
# inherit PID 1's exports, so hook the env file into .bashrc once.
if [ -f "$HOME/.bashrc" ] && ! grep -q "sync-llm-config" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<BASHRCEOF

# LLM endpoint shared with OpenCode (generated by sync-llm-config.sh)
if [ -f "\$HOME/.config/goose/set-env.sh" ]; then
  . "\$HOME/.config/goose/set-env.sh"
fi
BASHRCEOF
  echo "sync-llm-config: hooked set-env.sh into ~/.bashrc"
fi

echo "sync-llm-config: done (OpenCode + goose both point at $endpoint)"
