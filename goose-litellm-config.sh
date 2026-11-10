#!/bin/bash
# Configuration script for goose to use LiteLLM as LLM provider
# This script sets up the necessary environment variables and configuration
# for goose to work with LiteLLM

set -euo pipefail

echo "🦆 Configuring goose to use LiteLLM..."

# Create configuration directory
mkdir -p /home/appuser/.config/goose

# Create LiteLLM configuration file
cat > /home/appuser/.config/goose/litellm-config.yaml << 'EOF'
# LiteLLM Configuration for goose
# This file configures goose to use LiteLLM as the LLM provider

model_list:
  - model_name: "mistral-small"
    litellm_params:
      model: "mistral/mistral-small-latest"
      api_key: "${MISTRAL_API_KEY:-}"

  - model_name: "mistral-large"
    litellm_params:
      model: "mistral/mistral-large-latest"
      api_key: "${MISTRAL_API_KEY:-}"

  - model_name: "gpt-4"
    litellm_params:
      model: "openai/gpt-4"
      api_key: "${OPENAI_API_KEY:-}"
      api_base: "${OPENAI_API_BASE:-https://api.openai.com/v1}"

  - model_name: "gpt-3.5-turbo"
    litellm_params:
      model: "openai/gpt-3.5-turbo"
      api_key: "${OPENAI_API_KEY:-}"
      api_base: "${OPENAI_API_BASE:-https://api.openai.com/v1}"

  - model_name: "claude-3-opus"
    litellm_params:
      model: "anthropic/claude-3-opus-20240229"
      api_key: "${ANTHROPIC_API_KEY:-}"

  - model_name: "claude-3-sonnet"
    litellm_params:
      model: "anthropic/claude-3-sonnet-20240229"
      api_key: "${ANTHROPIC_API_KEY:-}"

  - model_name: "gemini-pro"
    litellm_params:
      model: "gemini/gemini-pro"
      api_key: "${GEMINI_API_KEY:-}"

  - model_name: "local-llama"
    litellm_params:
      model: "ollama/llama3"
      api_base: "http://localhost:11434"

general_settings:
  master_key: "${LITELLM_MASTER_KEY:-}"
  database_url: "${LITELLM_DATABASE_URL:-sqlite:///./litellm.db}"
  redis_url: "${REDIS_URL:-}"
  default_fallback_models:
    - "mistral-large"
    - "mistral-small"

router_settings:
  routing_strategy: "usage-based"
  enable_tag_filtering: true
  enable_model_alias: true

EOF

# Create environment variable setup script
cat > /home/appuser/.config/goose/set-env.sh << 'EOF'
#!/bin/bash
# Set up environment variables for goose with LiteLLM

# Export environment variables for LiteLLM.
# Mistral is the default: its block comes last so MISTRAL_API_KEY wins
# when several provider keys are set, and it is the fallback when none are.
if [ -n "${OPENAI_API_KEY:-}" ]; then
    export LITELLM_PROVIDER="openai"
    export LITELLM_MODEL="${OPENAI_MODEL:-gpt-4}"
fi

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    export LITELLM_PROVIDER="anthropic"
    export LITELLM_MODEL="${ANTHROPIC_MODEL:-claude-3-opus}"
fi

if [ -n "${GEMINI_API_KEY:-}" ]; then
    export LITELLM_PROVIDER="gemini"
    export LITELLM_MODEL="${GEMINI_MODEL:-gemini-pro}"
fi

if [ -n "${MISTRAL_API_KEY:-}" ]; then
    export LITELLM_PROVIDER="mistral"
    export LITELLM_MODEL="${MISTRAL_MODEL:-mistral-small}"
fi

# Set default values if not set (mistral default when no provider key matched)
export LITELLM_CONFIG_FILE="/home/appuser/.config/goose/litellm-config.yaml"
export GOOSE_LLM_PROVIDER="${LITELLM_PROVIDER:-mistral}"
export GOOSE_LLM_MODEL="${LITELLM_MODEL:-mistral-small-latest}"

echo "✅ LiteLLM environment configured"
echo "   Provider: ${GOOSE_LLM_PROVIDER}"
echo "   Model: ${GOOSE_LLM_MODEL}"
EOF

# Make the setup script executable
chmod +x /home/appuser/.config/goose/set-env.sh

# Create a wrapper script for goose with LiteLLM support
cat > /usr/local/bin/goose-litellm << 'EOF'
#!/bin/bash
# Wrapper script for goose with LiteLLM support

set -euo pipefail

# Source the environment setup
if [ -f "/home/appuser/.config/goose/set-env.sh" ]; then
    source /home/appuser/.config/goose/set-env.sh
fi

# Export additional environment variables for goose (mistral defaults)
export GOOSE_LLM_PROVIDER="${GOOSE_LLM_PROVIDER:-mistral}"
export GOOSE_LLM_MODEL="${GOOSE_LLM_MODEL:-mistral-small-latest}"

# Check if goose binary exists
if ! command -v goose >/dev/null 2>&1; then
    echo "Error: goose not found. Please install goose first." >&2
    exit 1
fi

# Run goose with the configured settings
echo "🦆 Starting goose with LiteLLM (Provider: ${GOOSE_LLM_PROVIDER}, Model: ${GOOSE_LLM_MODEL})"
goose "$@"
EOF

chmod +x /usr/local/bin/goose-litellm

# Create documentation
echo ""
echo "✅ LiteLLM configuration for goose has been set up!"
echo ""
echo "Configuration files created:"
echo "  - /home/appuser/.config/goose/litellm-config.yaml"
echo "  - /home/appuser/.config/goose/set-env.sh"
echo ""
echo "Wrapper script created:"
echo "  - /usr/local/bin/goose-litellm"
echo ""
echo "To use goose with LiteLLM, you can now run:"
echo "  goose-litellm session"
echo ""
echo "Or set up your API keys as environment variables:"
echo "  export OPENAI_API_KEY='your-key'"
echo "  export ANTHROPIC_API_KEY='your-key'"
echo "  export GEMINI_API_KEY='your-key'"
echo "  export MISTRAL_API_KEY='your-key'"
echo ""
echo "Then run:"
echo "  goose-litellm session"
echo ""
echo "Or configure specific models:"
echo "  export OPENAI_MODEL='gpt-4'"
echo "  goose-litellm session"

exit 0