FROM ubuntu:26.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    bzip2 \
    python3 \
    python3-pip \
    python3-yaml \
    nodejs \
    npm \
    jq \
    apt-transport-https ca-certificates gnupg \
    git \
    gh \
    wget \
    unzip \
    pipx \
    ripgrep \
    fzf \
    gnupg-utils \
    pinentry-curses \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 26.04 ships an embedded /usr/bin/pebble binary in the base image.
# It is unused here and currently trips Trivy on bundled Go CVEs.
RUN rm -f /usr/bin/pebble

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y kubectl \
    && rm -rf /var/lib/apt/lists/*

ARG GOOSE_VERSION=v1.50.0
COPY --chmod=755 scripts/install-goose.sh /usr/local/bin/install-goose.sh
RUN GOOSE_VERSION=${GOOSE_VERSION} GOOSE_BIN_DIR=/usr/local/bin /usr/local/bin/install-goose.sh \
    && /usr/local/bin/goose --version

# Option A (default): use the official opencode release from npm.
# Option B: use a self-built binary - place it at build/opencode/opencode
# before building (see README "Use a custom opencode build") and comment
# the npm install line below.
RUN npm install -g opencode-ai@latest
# COPY --chmod=755 build/opencode/opencode /usr/local/bin/opencode

# Install goosetown
RUN mkdir -p /app/goosetown
COPY goosetown/ /app/goosetown/

# Configure git for the appuser (override with your own identity at runtime,
# e.g. via a mounted ~/.gitconfig or `git config --global ...` in the shell)
RUN git config --global user.email "agent@example.com" \
    && git config --global user.name "agent"
RUN gh config set -h github.com git_protocol ssh

# The ubuntu base image ships a default 'ubuntu' user at uid 1000. Remove it
# and create appuser with a configurable uid/gid (default 1000) so host bind
# mounts line up with the host user running the container:
#   docker build --build-arg APP_UID=$(id -u) --build-arg APP_GID=$(id -g) .
# docker compose passes these via HOST_UID/HOST_GID (see docker-compose.yml
# and the Makefile). A group NAMED appuser always exists (required by the
# COPY --chown=appuser:appuser lines below); the user's primary gid is APP_GID
# so files created in bind mounts carry the host group.
ARG APP_UID=1000
ARG APP_GID=1000
RUN userdel -r ubuntu 2>/dev/null || true
RUN if getent group appuser >/dev/null 2>&1; then true; \
    elif getent group "$APP_GID" >/dev/null 2>&1; then groupadd appuser; \
    else groupadd -g "$APP_GID" appuser; fi \
    && useradd -m -u "$APP_UID" -g "$APP_GID" -s /bin/bash appuser

RUN mkdir -p /home/appuser/.local/share/opencode/skills /home/appuser/.local/share/opencode/repos /home/appuser/.ssh /home/appuser/.config/goosetown
RUN ssh-keyscan github.com >> /home/appuser/.ssh/known_hosts
COPY --chown=appuser:appuser skills/ /home/appuser/.config/opencode/skills/
COPY --chown=appuser:appuser scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh \
    && install -m 0755 /app/scripts/container-entrypoint.sh /usr/local/bin/container-entrypoint.sh \
    && ln -sf /app/scripts/opencode-run-with-metrics.sh /usr/local/bin/opencode-run-with-metrics.sh

# Copy goosetown scripts for appuser
COPY --chown=appuser:appuser goosetown/goose_gui /usr/local/bin/goose_gui
COPY --chown=appuser:appuser goosetown/gtwall /usr/local/bin/gtwall
COPY --chown=appuser:appuser goosetown/dashboard /usr/local/bin/goosetown-dashboard

RUN chown -R appuser:appuser /home/appuser/.local /home/appuser/.ssh /home/appuser/.config /app/goosetown /app/scripts \
    && mkdir -p /home/appuser/.config/goose \
    && chown -R appuser:appuser /home/appuser/.config/goose

# Create default LiteLLM configuration for goose.
# Mistral models are the default: listed first, used as fallbacks, and
# assumed when no provider key is set (GOOSE_LLM_MODEL default).
RUN mkdir -p /home/appuser/.config/goose \
  && printf '%s\n' \
    'model_list:' \
    '  - model_name: "mistral-small"' \
    '    litellm_params:' \
    '      model: "mistral/mistral-small-latest"' \
    '      api_key: "${MISTRAL_API_KEY:-}"' \
    '' \
    '  - model_name: "mistral-large"' \
    '    litellm_params:' \
    '      model: "mistral/mistral-large-latest"' \
    '      api_key: "${MISTRAL_API_KEY:-}"' \
    '' \
    '  - model_name: "gpt-4"' \
    '    litellm_params:' \
    '      model: "openai/gpt-4"' \
    '      api_key: "${OPENAI_API_KEY:-}"' \
    '      api_base: "${OPENAI_API_BASE:-https://api.openai.com/v1}"' \
    '' \
    '  - model_name: "gpt-3.5-turbo"' \
    '    litellm_params:' \
    '      model: "openai/gpt-3.5-turbo"' \
    '      api_key: "${OPENAI_API_KEY:-}"' \
    '      api_base: "${OPENAI_API_BASE:-https://api.openai.com/v1}"' \
    '' \
    '  - model_name: "claude-3-opus"' \
    '    litellm_params:' \
    '      model: "anthropic/claude-3-opus-20240229"' \
    '      api_key: "${ANTHROPIC_API_KEY:-}"' \
    '' \
    '  - model_name: "claude-3-sonnet"' \
    '    litellm_params:' \
    '      model: "anthropic/claude-3-sonnet-20240229"' \
    '      api_key: "${ANTHROPIC_API_KEY:-}"' \
    '' \
    '  - model_name: "gemini-pro"' \
    '    litellm_params:' \
    '      model: "gemini/gemini-pro"' \
    '      api_key: "${GEMINI_API_KEY:-}"' \
    '' \
    'general_settings:' \
    '  master_key: "${LITELLM_MASTER_KEY:-}"' \
    '  database_url: "${LITELLM_DATABASE_URL:-sqlite:///./litellm.db}"' \
    '  default_fallback_models:' \
    '    - "mistral-large"' \
    '    - "mistral-small"' \
    > /home/appuser/.config/goose/litellm-config.yaml

# Create wrapper script for goose with LiteLLM support
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -euo pipefail' \
    '' \
    'if [ -f "/home/appuser/.config/goose/set-env.sh" ]; then' \
    '    source /home/appuser/.config/goose/set-env.sh' \
    'fi' \
    '' \
    'export GOOSE_LLM_PROVIDER="${GOOSE_LLM_PROVIDER:-mistral}"' \
    'export GOOSE_LLM_MODEL="${GOOSE_LLM_MODEL:-mistral-small-latest}"' \
    '' \
    'if ! command -v goose >/dev/null 2>&1; then' \
    '    echo "Error: goose not found. Please install goose first." >&2' \
    '    exit 1' \
    'fi' \
    '' \
    'echo "Starting goose with LiteLLM (Provider: ${GOOSE_LLM_PROVIDER}, Model: ${GOOSE_LLM_MODEL})"' \
    'goose "$@"' \
    > /usr/local/bin/goose-litellm

RUN chmod +x /usr/local/bin/goose-litellm

# Set up goose and LiteLLM environment for appuser.
# NOTE: GOOSETOWN_DIR is NOT set here - the container entrypoint clones a
# goosetown working repository into the workspace and exports GOOSETOWN_DIR
# (plus GUIDES_DIR/PLANS_DIR/RESEARCH_DIR/WORK_LOGS_DIR) pointing at it.
# /app/goosetown remains in the image only as a tooling fallback.
RUN echo 'export PATH="/usr/local/bin:$PATH"' >> /home/appuser/.bashrc \
    && echo 'export GOOSE_LLM_PROVIDER="${GOOSE_LLM_PROVIDER:-mistral}"' >> /home/appuser/.bashrc \
    && echo 'export GOOSE_LLM_MODEL="${GOOSE_LLM_MODEL:-mistral-small-latest}"' >> /home/appuser/.bashrc \
    && echo 'export GOOSE_NO_ANALYTICS="1"' >> /home/appuser/.bashrc

# Thoth banner for interactive shells (docker compose exec thoth bash);
# non-interactive shells (bash -c) do not source .bashrc and stay clean
COPY --chown=appuser:appuser assets/thoth-banner.txt /home/appuser/.config/thoth-banner.txt
RUN printf '%s\n' \
    '# Thoth banner (interactive shells only)' \
    'if [ -n "$PS1" ] && [ -f "$HOME/.config/thoth-banner.txt" ]; then' \
    '    cat "$HOME/.config/thoth-banner.txt"' \
    'fi' >> /home/appuser/.bashrc

EXPOSE 9464
USER appuser
WORKDIR /app

# Copy opencode to goose mapping script
COPY --chown=appuser:appuser map-opencode-to-goose.sh /usr/local/bin/map-opencode-to-goose

# Make the mapping script executable
RUN chmod +x /usr/local/bin/map-opencode-to-goose

# Run opencode to goose mapping during build to pre-generate configuration
# This creates the configuration files even if no opencode config exists yet
RUN /usr/local/bin/map-opencode-to-goose

# Run entrypoint supports both opencode and goose/goosetown
ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
# CMD ["opencode"]
CMD ["bash"]
