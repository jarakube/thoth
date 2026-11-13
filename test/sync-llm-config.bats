#!/usr/bin/env bash
# Unit tests for scripts/sync-llm-config.sh - the single-source LLM
# configuration generator for OpenCode and goose.

bats_require_minimum_version 1.5.0

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"
  # hermetic: the running thoth container exports LLM_* env vars
  # (compose wiring) that would leak into the tests and change the
  # defaults under assertion
  unset LLM_ENDPOINT LLM_API_KEY_ENV LLM_MODELS LLM_DEFAULT_MODEL || true
  SYNC="$BATS_TEST_DIRNAME/../scripts/sync-llm-config.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "no-op when LLM_ENDPOINT is unset" {
  unset LLM_ENDPOINT
  run bash "$SYNC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
  [ ! -e "$HOME/.config/opencode/opencode.json" ]
}

@test "generates opencode.json with the openai-compatible provider" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  run bash "$SYNC"
  [ "$status" -eq 0 ]
  cfg="$HOME/.config/opencode/opencode.json"
  [ -f "$cfg" ]
  [ "$(stat -c %a "$cfg")" = "600" ]
  [ "$(jq -r '.provider.litellm.npm' "$cfg")" = "@ai-sdk/openai-compatible" ]
  [ "$(jq -r '.provider.litellm.options.baseURL' "$cfg")" = "http://proxy.example:4000/v1" ]
}

@test "default models land in the provider config" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  bash "$SYNC"
  cfg="$HOME/.config/opencode/opencode.json"
  [ "$(jq -r '.provider.litellm.models["mistral-small-latest"].name' "$cfg")" = "mistral-small-latest" ]
  [ "$(jq -r '.provider.litellm.models["mistral-large-latest"].name' "$cfg")" = "mistral-large-latest" ]
  [ "$(jq -r '.model' "$cfg")" = "litellm/mistral-small-latest" ]
}

@test "LLM_MODELS overrides the model list (comma form)" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  export LLM_MODELS="model-a,model-b"
  bash "$SYNC"
  cfg="$HOME/.config/opencode/opencode.json"
  [ "$(jq -r '.provider.litellm.models | length' "$cfg")" = "2" ]
  [ -n "$(jq -r '.provider.litellm.models["model-a"]' "$cfg")" ]
  [ -n "$(jq -r '.provider.litellm.models["model-b"]' "$cfg")" ]
  [ "$(jq -r '.model' "$cfg")" = "litellm/model-a" ]
}

@test "LLM_DEFAULT_MODEL wins over the first LLM_MODELS entry" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  export LLM_MODELS="model-a model-b"
  export LLM_DEFAULT_MODEL="model-b"
  bash "$SYNC"
  cfg="$HOME/.config/opencode/opencode.json"
  [ "$(jq -r '.model' "$cfg")" = "litellm/model-b" ]
}

@test "key from env var is embedded in opencode.json" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  export CUSTOM_LITELLM_API_KEY="sk-from-env-123"
  bash "$SYNC"
  cfg="$HOME/.config/opencode/opencode.json"
  [ "$(jq -r '.provider.litellm.options.apiKey' "$cfg")" = "sk-from-env-123" ]
}

@test "key from the compose secret file is embedded (env unset)" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  unset CUSTOM_LITELLM_API_KEY || true
  mkdir -p "$TEST_DIR/secrets"
  printf 'sk-from-secret-456\n' > "$TEST_DIR/secrets/llm_api_key"
  # the sync script reads /run/secrets/llm_api_key - point it at the test
  # file via a bind-style override: run in a mount namespace is overkill;
  # instead we temporarily create the path (test runs as the same user)
  # - use unshare if available, else skip
  if command -v unshare >/dev/null 2>&1 && unshare -m true 2>/dev/null; then
    unshare -m bash -c "
      mkdir -p /run/secrets 2>/dev/null || true
      [ -w /run/secrets ] && cp '$TEST_DIR/secrets/llm_api_key' /run/secrets/llm_api_key
      HOME='$HOME' LLM_ENDPOINT='$LLM_ENDPOINT' bash '$SYNC'
    "
    cfg="$HOME/.config/opencode/opencode.json"
    [ "$(jq -r '.provider.litellm.options.apiKey' "$cfg")" = "sk-from-secret-456" ]
  else
    skip "unshare not available for the /run/secrets override"
  fi
}

@test "without any key: env reference is written, marked in output" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  unset CUSTOM_LITELLM_API_KEY || true
  run bash "$SYNC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"env reference, no key yet"* ]]
  cfg="$HOME/.config/opencode/opencode.json"
  [ "$(jq -r '.provider.litellm.options.apiKey' "$cfg")" = "{env:CUSTOM_LITELLM_API_KEY}" ]
}

@test "goose set-env.sh: host split from /v1, key embedded with env precedence" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  export CUSTOM_LITELLM_API_KEY="sk-embed-789"
  bash "$SYNC"
  env_file="$HOME/.config/goose/set-env.sh"
  [ -f "$env_file" ]
  [ "$(stat -c %a "$env_file")" = "600" ]
  grep -q 'export LITELLM_HOST="http://proxy.example:4000"' "$env_file"
  grep -q 'export LITELLM_BASE_PATH="v1/chat/completions"' "$env_file"
  grep -q 'sk-embed-789' "$env_file"
  # env var takes precedence at source time
  # shellcheck disable=SC1090
  source "$env_file"
  [ "$LITELLM_HOST" = "http://proxy.example:4000" ]
  [ "$LITELLM_API_KEY" = "sk-embed-789" ]
}

@test "goose set-env.sh: no-key variant references the env var" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  unset CUSTOM_LITELLM_API_KEY || true
  bash "$SYNC"
  env_file="$HOME/.config/goose/set-env.sh"
  grep -q 'export CUSTOM_LITELLM_API_KEY="${CUSTOM_LITELLM_API_KEY:-}"' "$env_file"
}

@test "endpoint without /v1 is kept as host root for goose" {
  export LLM_ENDPOINT="http://proxy.example:4000"
  bash "$SYNC"
  env_file="$HOME/.config/goose/set-env.sh"
  # no /v1 to strip: host stays complete
  grep -q 'export LITELLM_HOST="http://proxy.example:4000"' "$env_file"
}

@test "existing opencode.json keys are preserved on re-run" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  mkdir -p "$HOME/.config/opencode"
  printf '{"theme":"dark","provider":{"other":{"npm":"x"}}}' \
    > "$HOME/.config/opencode/opencode.json"
  bash "$SYNC"
  cfg="$HOME/.config/opencode/opencode.json"
  [ "$(jq -r '.theme' "$cfg")" = "dark" ]
  [ "$(jq -r '.provider.other.npm' "$cfg")" = "x" ]
  [ "$(jq -r '.provider.litellm.npm' "$cfg")" = "@ai-sdk/openai-compatible" ]
}

@test "goose config.yaml: GOOSE_PROVIDER set only when absent" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  mkdir -p "$HOME/.config/goose"
  printf 'GOOSE_PROVIDER: "openai"\n' > "$HOME/.config/goose/config.yaml"
  bash "$SYNC"
  grep -q 'GOOSE_PROVIDER: "openai"' "$HOME/.config/goose/config.yaml"
  # and when absent:
  rm "$HOME/.config/goose/config.yaml"
  bash "$SYNC"
  grep -q 'GOOSE_PROVIDER: "litellm"' "$HOME/.config/goose/config.yaml"
}

@test "GOOSE_MODEL is updated in place on re-run" {
  export LLM_ENDPOINT="http://proxy.example:4000/v1"
  bash "$SYNC"
  grep -q 'GOOSE_MODEL: "mistral-small-latest"' "$HOME/.config/goose/config.yaml"
  export LLM_DEFAULT_MODEL="mistral-large-latest"
  bash "$SYNC"
  grep -q 'GOOSE_MODEL: "mistral-large-latest"' "$HOME/.config/goose/config.yaml"
}
