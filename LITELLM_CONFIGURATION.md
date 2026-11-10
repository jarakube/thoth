# LiteLLM Configuration

This document explains how to configure the agents in this container to use
**LiteLLM** as the LLM provider.

## Overview

[LiteLLM](https://litellm.ai/) is a proxy server that allows you to use 100+ LLMs (OpenAI, Anthropic, Google, Mistral, Local models via Ollama, etc.) with a unified OpenAI-compatible API. Since LiteLLM speaks the OpenAI API format, agents connect to it the same way they connect to any OpenAI-compatible endpoint - there is no "litellm" provider type in either OpenCode or goose.

- **goose**: configured via the LiteLLM config file and the `goose-litellm`
  wrapper described below.
- **OpenCode**: configured as a custom provider using the
  `openai-compatible` runtime package - see
  [Using LiteLLM with OpenCode](#using-litellm-with-opencode) below.

## What's Included (goose)

The Dockerfile includes:

1. **LiteLLM Configuration File** (`/home/appuser/.config/goose/litellm-config.yaml`)
   - Pre-configured models for Mistral (default), OpenAI, Anthropic, and Google
   - Environment variable placeholders for API keys
   - Default fallback models

2. **Wrapper Script** (`/usr/local/bin/goose-litellm`)
   - Automatically sets up environment for LiteLLM
   - Provides goose with LiteLLM support
   - Easy to use command: `goose-litellm`

3. **Environment Variables**
   - `GOOSE_LLM_PROVIDER` - Set the LLM provider (e.g., "mistral", "openai", "anthropic")
   - `GOOSE_LLM_MODEL` - Set the specific model to use
   - Standard API key environment variables for each provider

## Supported Providers

The configuration includes support for:

| Provider | Models | Environment Variable |
|----------|--------|---------------------|
| **OpenAI** | gpt-4, gpt-3.5-turbo | `OPENAI_API_KEY` |
| **Anthropic** | claude-3-opus, claude-3-sonnet | `ANTHROPIC_API_KEY` |
| **Google** | gemini-pro | `GEMINI_API_KEY` |
| **Mistral** | mistral-small, mistral-large | `MISTRAL_API_KEY` |
| **Ollama** | llama3, other local models | `OLLAMA_API_BASE` |

## Quick Start

`CUSTOM_LITELLM_API_KEY` is required and must be set before using the LiteLLM-backed Goose commands.

### Method 1: Using Environment Variables (Recommended)

```bash
# Required for LiteLLM access
export CUSTOM_LITELLM_API_KEY="your-litellm-key"

# Set your API keys
export OPENAI_API_KEY="your-openai-key"
export ANTHROPIC_API_KEY="your-anthropic-key"

# Choose provider and model
export GOOSE_LLM_PROVIDER="openai"
export GOOSE_LLM_MODEL="gpt-4"

# Run goose with LiteLLM support
goose-litellm session "Analyze this codebase"
```

### Method 2: Using the Wrapper Script

```bash
# Run goose with default LiteLLM configuration
goose-litellm session "Help me debug this Python code"
```

### Method 3: Direct goose Usage

```bash
# Set environment variables
export OPENAI_API_KEY="your-key"

# Run goose directly (it will use LiteLLM if configured)
goose session "Review my Dockerfile"
```

## Configuration Files

### LiteLLM Config File
Location: `/home/appuser/.config/goose/litellm-config.yaml`

This file contains:
- Model definitions with provider-specific parameters
- Environment variable placeholders for API keys
- Default settings for LiteLLM

You can customize this file to add more models or change settings.

### Environment Setup
Location: `/home/appuser/.config/goose/set-env.sh` (created when you run the config script)

This script sets up environment variables based on your API keys.

## Advanced Configuration

### Adding Custom Models

Edit `/home/appuser/.config/goose/litellm-config.yaml`:

```yaml
model_list:
  - model_name: "my-custom-model"
    litellm_params:
      model: "custom-provider/custom-model-name"
      api_key: "${CUSTOM_API_KEY:-}"
      api_base: "${CUSTOM_API_BASE:-https://api.custom.com/v1}"
      other_param: "value"
```

### Using Local Models (Ollama)

```bash
# Start Ollama
docker run -d -p 11434:11434 --name ollama ollama/ollama

# Pull a model
curl -X POST http://localhost:11434/api/pull -d '{"name": "llama3"}'

# Set environment variables
export OLLAMA_API_BASE="http://localhost:11434"

# Configure goose to use local model
export GOOSE_LLM_PROVIDER="ollama"
export GOOSE_LLM_MODEL="llama3"

goose-litellm session "Explain this code"
```

### Multiple Providers with Fallback

LiteLLM supports routing strategies and fallback models. You can configure this in the YAML file:

```yaml
general_settings:
  default_fallback_models:
    - "mistral-large"
    - "mistral-small"

router_settings:
  routing_strategy: "usage-based"
  enable_tag_filtering: true
```

## Environment Variables Reference

### Provider-Specific Variables

| Provider | API Key Variable | Model Variable | API Base Variable |
|----------|------------------|----------------|-------------------|
| OpenAI | `OPENAI_API_KEY` | `OPENAI_MODEL` | `OPENAI_API_BASE` |
| Anthropic | `ANTHROPIC_API_KEY` | `ANTHROPIC_MODEL` | N/A |
| Google | `GEMINI_API_KEY` | `GEMINI_MODEL` | N/A |
| Mistral | `MISTRAL_API_KEY` | `MISTRAL_MODEL` | N/A |
| Ollama | N/A | `OLLAMA_MODEL` | `OLLAMA_API_BASE` |

### Goose-Specific Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GOOSE_LLM_PROVIDER` | LLM provider to use | `mistral` |
| `GOOSE_LLM_MODEL` | Specific model to use | `mistral-small-latest` |
| `LITELLM_CONFIG_FILE` | Path to LiteLLM config | `/home/appuser/.config/goose/litellm-config.yaml` |

### LiteLLM-Specific Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `CUSTOM_LITELLM_API_KEY` | Required API key for LiteLLM access | (required) |
| `LITELLM_MASTER_KEY` | Master key for LiteLLM | (empty) |
| `LITELLM_DATABASE_URL` | Database connection string | `sqlite:///./litellm.db` |
| `REDIS_URL` | Redis connection string | (empty) |

## Troubleshooting

### Issue: "Model not found"

**Solution**: Make sure the model name in your environment variable matches one of the configured models in the YAML file.

```bash
# Wrong
export GOOSE_LLM_MODEL="gpt-4o"

# Correct
export GOOSE_LLM_MODEL="gpt-4"
```

### Issue: "API key not set"

**Solution**: Export `CUSTOM_LITELLM_API_KEY` and the required provider API key environment variable.

```bash
# Required for LiteLLM
export CUSTOM_LITELLM_API_KEY="your-litellm-key"

# For OpenAI
export OPENAI_API_KEY="sk-..."

# For Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Issue: "LiteLLM not working"

**Solution**: Verify that goose is installed and the wrapper script exists:

```bash
ls -la /usr/local/bin/goose-litellm
which goose
```

### Issue: "Connection refused"

**Solution**: Check that your API base URL is correct:

```bash
# For custom providers
export OPENAI_API_BASE="https://api.openai.com/v1"
```

## Examples

### Example 1: Using OpenAI GPT-4

```bash
# Set API key
export OPENAI_API_KEY="sk-your-openai-key-here"

# Configure goose
export GOOSE_LLM_PROVIDER="openai"
export GOOSE_LLM_MODEL="gpt-4"

# Run goose
goose-litellm session "Review this Kubernetes deployment YAML"
```

### Example 2: Using Anthropic Claude 3 Opus

```bash
# Set API key
export ANTHROPIC_API_KEY="sk-ant-your-anthropic-key-here"

# Configure goose
export GOOSE_LLM_PROVIDER="anthropic"
export GOOSE_LLM_MODEL="claude-3-opus"

# Run goose
goose-litellm session "Explain this complex algorithm"
```

### Example 3: Using Local Ollama Model

```bash
# Start Ollama (if not running)
docker run -d -p 11434:11434 --name ollama ollama/ollama

# Pull a model
curl -X POST http://localhost:11434/api/pull -d '{"name": "llama3"}'

# Configure goose
export GOOSE_LLM_PROVIDER="ollama"
export GOOSE_LLM_MODEL="llama3"

# Run goose
goose-litellm session "Help me understand this Python code"
```

### Example 4: Multi-Provider with Fallback

```bash
# Set multiple API keys
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."

# Configure LiteLLM config for fallback
export GOOSE_LLM_PROVIDER="mistral"

# Run goose - it will use the best available model
goose-litellm session "Analyze this entire codebase"
```

## Performance Tips

1. **Use smaller models** for quick tasks (mistral-small, gpt-3.5-turbo)
2. **Use larger models** for complex analysis (claude-3-opus, gpt-4)
3. **Set up caching** with LiteLLM to reduce API costs
4. **Use local models** for privacy-sensitive code
5. **Monitor usage** with LiteLLM's built-in dashboard

## Security Considerations

✅ **Secure by default**:
- API keys are not hardcoded in the container
- Keys are passed via environment variables
- Configuration files are owned by appuser
- No sensitive data is stored in the image

🔒 **Best Practices**:
- Use Kubernetes secrets or Docker secrets for production
- Rotate API keys regularly
- Use different keys for different environments
- Never commit API keys to version control

## Integration with Goosetown

When using goose with goosetown, the LiteLLM configuration works seamlessly:

```bash
# Start goosetown orchestrator
goose load source:goosetown-orchestrator

# Configure goose first
export OPENAI_API_KEY="your-key"
export GOOSE_LLM_PROVIDER="openai"

# Then agents will use LiteLLM automatically
```

## Using LiteLLM with OpenCode

OpenCode has no native "litellm" provider - and it does not need one.
LiteLLM exposes an OpenAI-compatible API, so OpenCode connects to it as a
custom provider using the `@ai-sdk/openai-compatible` package.

Add this to `~/.config/opencode/opencode.json` (global) or `opencode.json`
in your project:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "litellm/mistral-small-latest",
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LiteLLM Proxy",
      "options": {
        "baseURL": "http://litellm-proxy:4000/v1",
        "apiKey": "{env:CUSTOM_LITELLM_API_KEY}"
      },
      "models": {
        "mistral-small-latest": { "name": "Mistral Small (via LiteLLM)" },
        "mistral-large-latest": { "name": "Mistral Large (via LiteLLM)" }
      }
    }
  }
}
```

Notes:

- `npm` selects the OpenAI-compatible runtime package; LiteLLM speaks the
  OpenAI API format, so no litellm-specific package is needed.
- `options.apiKey` reads the credential from the `CUSTOM_LITELLM_API_KEY`
  environment variable via the `{env:...}` placeholder (this container's
  compose setup passes that variable). Alternatively run `/connect` and
  pick the `litellm` provider to store the key in `auth.json`.
- `options.baseURL` must point at the LiteLLM proxy's `/v1` endpoint.
  Adjust the host to wherever your proxy runs (`http://localhost:4000/v1`
  when the proxy runs on the same machine, `http://host.docker.internal:4000/v1`
  from inside a container, a service name on a Docker network, etc.).
- Each key under `models` must match an ID the proxy's `GET /v1/models`
  returns; the reference format is `litellm/<model-id>`
  (e.g. `litellm/mistral-small-latest`).

Verify inside the container:

```bash
opencode models litellm
opencode run --model litellm/mistral-small-latest "Reply with OK"
```

(Verified with OpenCode 1.19.5: the provider appears in
`opencode models litellm` and requests route to the configured baseURL.)

> **OpenCode V2**: if you upgrade to OpenCode V2, the config schema
> changes to `providers` (plural) with a `package` field instead of
> `npm`:
>
> ```jsonc
> {
>   "providers": {
>     "litellm": {
>       "name": "LiteLLM Proxy",
>       "env": ["CUSTOM_LITELLM_API_KEY"],
>       "package": "@opencode/ai/providers/openai-compatible",
>       "settings": { "baseURL": "http://litellm-proxy:4000/v1" },
>       "models": { "mistral-small-latest": { "name": "Mistral Small (via LiteLLM)" } }
>     }
>   }
> }
> ```

## Documentation References

- [LiteLLM Official Documentation](https://docs.litellm.ai/)
- [Goose Documentation](https://goose-docs.ai/)
- [Goose GitHub Repository](https://github.com/aaif-goose/goose)
- [LiteLLM GitHub Repository](https://github.com/BerriAI/litellm)
- [OpenCode Providers Documentation](https://opencode.ai/docs/providers/) (custom providers / `openai-compatible` package)

## Support

If you encounter issues with LiteLLM configuration:

1. Check the LiteLLM logs: `docker logs litellm`
2. Verify API keys are correct
3. Test LiteLLM directly: `curl http://localhost:4000/chat/completions`
4. Check goose configuration: `goose doctor`

---

**Status**: ✅ **COMPLETE**
**Date**: 2026-09-04
**Configuration**: Ready for use with all major LLM providers
