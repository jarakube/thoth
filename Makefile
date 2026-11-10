# Convenience wrapper around docker compose.
# Passes the host user's uid/gid so the in-container appuser matches the
# host user and bind mounts are writable without any chown.

HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

# pass (the standard Unix password store) entry holding the LLM API key.
# Set PASS_LLM_ENTRY to your own path; `make up` wires it into the
# compose secret automatically when pass is installed and the entry
# exists. Without pass, set the key in .env (CUSTOM_LITELLM_API_KEY) or
# point LLM_API_KEY_FILE at a file yourself.
PASS_LLM_ENTRY ?= llm/thoth-api-key

.PHONY: up down build shell run logs ps clean

# Start the agent in the background (builds if needed).
# When `pass` is installed and the entry PASS_LLM_ENTRY exists, the LLM
# API key is exported from pass into a temporary file (mode 600) and
# mounted as the llm_api_key compose secret - it never lands in .env,
# `docker inspect`, or the image. Otherwise the secret stays empty and
# the key can be set via .env as before.
up:
	@set -e; \
	keyfile=""; \
	if command -v pass >/dev/null 2>&1 && pass show $(PASS_LLM_ENTRY) >/dev/null 2>&1; then \
	  keyfile="/tmp/thoth-llm-key.$$$$"; \
	  pass show $(PASS_LLM_ENTRY) | head -n1 > "$$keyfile"; chmod 600 "$$keyfile"; \
	  echo "make: LLM key loaded from pass entry '$(PASS_LLM_ENTRY)'"; \
	else \
	  echo "make: pass entry '$(PASS_LLM_ENTRY)' not available - starting without key secret"; \
	fi; \
	trap 'test -n "$$keyfile" && rm -f "$$keyfile"' EXIT; \
	LLM_API_KEY_FILE="$$keyfile" HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) \
	  docker compose up -d --build

# Stop the agent (volumes and host bind mounts are preserved)
down:
	docker compose down

# Build the image with the host user's uid/gid
build:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) docker compose build

# Interactive shell in the running agent
shell:
	docker compose exec thoth bash

# One-shot: docker compose run --rm thoth <CMD...>
# Usage: make run CMD="opencode --version"
run:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) docker compose run --rm thoth $(CMD)

logs:
	docker compose logs -f thoth

ps:
	docker compose ps

# Remove containers AND the opencode-data named volume.
# Host bind mounts (workspace/, share/opencode-runs/) are never touched.
clean:
	docker compose down -v
