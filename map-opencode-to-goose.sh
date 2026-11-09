#!/bin/bash
# Script to map opencode configuration to goose configuration
# This script runs at container startup and creates goose configuration
# based on existing opencode configuration

set -euo pipefail

echo "🔄 Mapping opencode configuration to goose..."

# Create configuration directory if it doesn't exist
mkdir -p /home/appuser/.config/goose

# Check if opencode configuration exists
if [ -f "/home/appuser/.config/opencode/config.yaml" ] || [ -f "/home/appuser/.config/opencode/settings.json" ]; then
    echo "✅ Found opencode configuration, creating goose mapping..."
    
    # Create goose configuration based on opencode settings
    cat > /home/appuser/.config/goose/opencode-mapping.yaml << 'EOF'
# Opencode to Goose Configuration Mapping
# This file maps opencode settings to goose configuration
# Generated automatically at container startup

# ============================================
# LLM Provider Configuration
# ============================================

llm_provider:
  # Map opencode LLM provider to goose
  # Common opencode providers: openai, anthropic, google, mistral, ollama
  
  # Try to detect provider from environment or opencode config
  detected_provider: "${OPENCODE_LLM_PROVIDER:-custom}"
  detected_model: "${OPENCODE_LLM_MODEL:-mistral-small-latest}"

# ============================================
# API Key Mapping
# ============================================

api_keys:
  # OpenAI
  openai_api_key: "${OPENAI_API_KEY:-${OPENCODE_OPENAI_API_KEY:-}}"
  openai_model: "${OPENAI_MODEL:-${OPENCODE_OPENAI_MODEL:-gpt-4}}"
  
  # Anthropic
  anthropic_api_key: "${ANTHROPIC_API_KEY:-${OPENCODE_ANTHROPIC_API_KEY:-}}"
  anthropic_model: "${ANTHROPIC_MODEL:-${OPENCODE_ANTHROPIC_MODEL:-claude-3-opus}}"
  
  # Google
  google_api_key: "${GEMINI_API_KEY:-${OPENCODE_GEMINI_API_KEY:-}}"
  google_model: "${GEMINI_MODEL:-${OPENCODE_GEMINI_MODEL:-gemini-pro}}"
  
  # Mistral
  mistral_api_key: "${MISTRAL_API_KEY:-${OPENCODE_MISTRAL_API_KEY:-}}"
  mistral_model: "${MISTRAL_MODEL:-${OPENCODE_MISTRAL_MODEL:-mistral-small}}"
  
  # Ollama (local models)
  ollama_base_url: "${OLLAMA_API_BASE:-${OPENCODE_OLLAMA_API_BASE:-http://localhost:11434}}"
  ollama_model: "${OLLAMA_MODEL:-${OPENCODE_OLLAMA_MODEL:-llama3}}"

# ============================================
# Goose Configuration
# ============================================

goose_settings:
  provider: "${GOOSE_LLM_PROVIDER:-${OPENCODE_LLM_PROVIDER:-custom}}"
  model: "${GOOSE_LLM_MODEL:-${OPENCODE_LLM_MODEL:-mistral-small-latest}}"
  
  # Telemetry and logging
  telemetry_enabled: "${GOOSE_TELEMETRY:-${OPENCODE_TELEMETRY:-false}}"
  log_level: "${GOOSE_LOG_LEVEL:-${OPENCODE_LOG_LEVEL:-info}}"
  
  # MCP Server settings
  mcp_server_enabled: "${GOOSE_MCP_ENABLED:-${OPENCODE_MCP_ENABLED:-true}}"
  mcp_server_port: "${GOOSE_MCP_PORT:-${OPENCODE_MCP_PORT:-3000}}"
  
  # Session settings
  session_timeout_minutes: "${GOOSE_SESSION_TIMEOUT:-${OPENCODE_SESSION_TIMEOUT:-30}}"
  max_concurrent_agents: "${GOOSE_MAX_AGENTS:-${OPENCODE_MAX_AGENTS:-5}}"

# ============================================
# Goosetown Configuration
# ============================================

goosetown_settings:
  enabled: "${GOOSETOWN_ENABLED:-${OPENCODE_GOSETOWN_ENABLED:-true}}"
  orchestrator_model: "${GOOSETOWN_ORCHESTRATOR_MODEL:-${OPENCODE_ORCHESTRATOR_MODEL:-gpt-4}}"
  research_model: "${GOOSETOWN_RESEARCHER_MODEL:-${OPENCODE_RESEARCHER_MODEL:-claude-3-sonnet}}"
  review_model: "${GOOSETOWN_REVIEWER_MODEL:-${OPENCODE_REVIEWER_MODEL:-mistral-large}}"
  
  # Wall settings
  wall_enabled: "${GOOSETOWN_WALL_ENABLED:-${OPENCODE_WALL_ENABLED:-true}}"
  wall_file: "${GOOSETOWN_WALL_FILE:-${OPENCODE_WALL_FILE:-/tmp/goosetown-wall.log}}"
  
  # Telepathy settings
  telepathy_enabled: "${GOOSETOWN_TELEPATHY:-${OPENCODE_TELEPATHY:-true}}"
  telepathy_file: "${GOOSETOWN_TELEPATHY_FILE:-${OPENCODE_TELEPATHY_FILE:-/tmp/goosetown-telepathy.txt}}"
EOF

# ============================================
# Environment Variable Export Script
# ============================================

# This script sets up the environment for goose based on opencode config
cat > /home/appuser/.config/goose/setup-goose-env.sh << 'SETUP_EOF'
#!/bin/bash
# Setup goose environment based on opencode configuration

set -euo pipefail

echo "🔄 Setting up goose environment from opencode configuration..."

# Source opencode environment if available
if [ -f "/home/appuser/.config/opencode/env" ]; then
    source /home/appuser/.config/opencode/env
fi

# Source opencode config if available
if [ -f "/home/appuser/.config/opencode/config.yaml" ]; then
    # Parse YAML-like config for LLM settings
    if grep -q "llm_provider:" /home/appuser/.config/opencode/config.yaml 2>/dev/null; then
        if grep -q "openai" /home/appuser/.config/opencode/config.yaml 2>/dev/null; then
            export GOOSE_LLM_PROVIDER="openai"
            export OPENAI_API_KEY="${OPENCODE_OPENAI_API_KEY:-${OPENAI_API_KEY:-}}"
        elif grep -q "anthropic" /home/appuser/.config/opencode/config.yaml 2>/dev/null; then
            export GOOSE_LLM_PROVIDER="anthropic"
            export ANTHROPIC_API_KEY="${OPENCODE_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-}}"
        fi
    fi
fi

# Set default goose model based on provider
export GOOSE_LLM_MODEL="${GOOSE_LLM_MODEL:-mistral-small-latest}"

# Set goosetown environment
export GOOSETOWN_DIR="/app/goosetown"
export PYTHONPATH="/app/goosetown:${PYTHONPATH:-}"

# Set telemetry based on opencode settings
export GOOSE_TELEMETRY="${OPENCODE_TELEMETRY:-false}"

# Set log level
export GOOSE_LOG_LEVEL="${OPENCODE_LOG_LEVEL:-info}"

# Set MCP server
export GOOSE_MCP_ENABLED="${OPENCODE_MCP_ENABLED:-true}"
export GOOSE_MCP_PORT="${OPENCODE_MCP_PORT:-3000}"

echo "✅ Goose environment configured:"
echo "   Provider: ${GOOSE_LLM_PROVIDER:-custom}"
echo "   Model: ${GOOSE_LLM_MODEL}"
echo "   Telemetry: ${GOOSE_TELEMETRY}"
echo "   Goosetown: ${GOOSETOWN_DIR}"
SETUP_EOF

    # Make the setup script executable
    chmod +x /home/appuser/.config/goose/setup-goose-env.sh
    
    # Create a wrapper script that sets up goose environment before running goose
    if [ -w /usr/local/bin ]; then
    cat > /usr/local/bin/goose-opencode << 'WRAPPER_EOF'
#!/bin/bash
# Wrapper script that maps opencode configuration to goose

set -euo pipefail

# Source the goose environment setup
if [ -f "/home/appuser/.config/goose/setup-goose-env.sh" ]; then
    source /home/appuser/.config/goose/setup-goose-env.sh
fi

# Check if goose binary exists
if ! command -v goose >/dev/null 2>&1; then
    echo "Error: goose not found. Please install goose first." >&2
    exit 1
fi

# Check if opencode configuration exists
if [ -f "/home/appuser/.config/opencode/config.yaml" ]; then
    echo "🔄 Using opencode configuration mapped to goose"
else
    echo "ℹ️ No opencode configuration found, using default goose settings"
fi

# Run goose with the configured settings
echo "🦆 Starting goose (Provider: ${GOOSE_LLM_PROVIDER:-custom}, Model: ${GOOSE_LLM_MODEL:-mistral-small-latest})"
goose "$@"
WRAPPER_EOF
    
    chmod +x /usr/local/bin/goose-opencode
    
    # Create a symlink for goose-litellm to also use opencode mapping
    ln -sf /usr/local/bin/goose-opencode /usr/local/bin/goose-opencode-litellm 2>/dev/null || true
    
    echo "✅ Created goose-opencode wrapper script"
    echo "   Available at: /usr/local/bin/goose-opencode"
    echo "   Usage: goose-opencode session 'your prompt'"
    else
        echo "ℹ️ Skipping /usr/local/bin wrapper creation; directory is not writable"
    fi
    
else
    echo "ℹ️ No opencode configuration found, using default goose settings"
fi

if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
cat > /etc/profile.d/goose-opencode.sh << 'PROFILE_EOF'
#!/bin/bash
# Goose-Opencode integration notification

GOOSE_CONFIGURED=false

# Check if goose-opencode wrapper exists
if [ -f "/usr/local/bin/goose-opencode" ]; then
    GOOSE_CONFIGURED=true
fi

if [ "$GOOSE_CONFIGURED" = true ]; then
    echo ""
    echo "🦆 Goose + Opencode Integration Active"
    echo "   Use 'goose-opencode' to run goose with opencode configuration mapping"
    echo "   Example: goose-opencode session 'Analyze this code'"
    echo ""
fi
PROFILE_EOF

chmod +x /etc/profile.d/goose-opencode.sh
else
    echo "ℹ️ Skipping /etc/profile.d notification script; directory is not writable"
fi

echo ""
echo "✅ Opencode to goose configuration mapping complete!"
echo ""
echo "Available commands:"
echo "  - goose-opencode: Run goose with opencode configuration mapping"
echo "  - goose-litellm: Run goose with LiteLLM support"
echo "  - goose: Direct goose usage"
echo ""
echo "Configuration files created:"
echo "  - /home/appuser/.config/goose/opencode-mapping.yaml"
echo "  - /home/appuser/.config/goose/setup-goose-env.sh"
echo ""

# Export environment variables for immediate use
export GOOSE_OPENCE_MAPPING_ENABLED="true"

exit 0
