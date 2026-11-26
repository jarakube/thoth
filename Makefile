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

# Same pattern for the Mistral API key (Vibe CLI / goose mistral
# provider): `make up` wires the pass entry into the mistral_api_key
# compose secret; the entrypoint exports it as MISTRAL_API_KEY.
PASS_MISTRAL_ENTRY ?= llm/thoth-mistral-api-key

.PHONY: up down build shell run logs ps clean test suricata-init suricata-up suricata-down suricata-report block-egress

# --- Suricata IDS sidecar (opt-in) ----------------------------------------

# One-time: validate the versioned sensor config (suricata/config/)
suricata-init:
	./scripts/init-suricata.sh

# Start thoth + the suricata sidecar (shares thoth's network namespace,
# passively captures on eth0, writes suricata/logs/eve.json). Loads both
# API keys (LLM + Mistral) from pass like `make up`.
suricata-up:
	@set -e; \
	$(load-llm-key); \
	$(load-mistral-key); \
	trap 'test -n "$$keyfile" && rm -f "$$keyfile"; test -n "$$mistral_keyfile" && rm -f "$$mistral_keyfile"' EXIT; \
	LLM_API_KEY_FILE="$$keyfile" MISTRAL_API_KEY_FILE="$$mistral_keyfile" HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) \
	  docker compose -f docker-compose.yml -f docker-compose.suricata.yml up -d

# Overview report of the captured traffic: hosts, egress/ingress
# volumes, recent connections (from suricata/logs/eve.json)
suricata-report:
	./scripts/suricata-report.sh

# --- Egress blocking (agent firewall) -------------------------------------

# Block outgoing traffic from the agent container:
#   make block-egress ARGS="add <ip|domain>"     # block an IP or domain (all its IPs)
#   make block-egress ARGS="list"                # show active blocks
#   make block-egress ARGS="remove <ip|domain>"  # remove one block
#   make block-egress ARGS="clear"               # remove all blocks
#   make block-egress ARGS="refresh"             # re-apply suricata/blocklist
block-egress:
	./scripts/block-egress.sh $(ARGS)

# Stop both (config/logs/data persist on the host)
suricata-down:
	docker compose -f docker-compose.yml -f docker-compose.suricata.yml down

# Unit tests (bats) for the entrypoint and sync scripts - host-side,
# no container needed; test/run-tests.sh installs bats if missing
test:
	./test/run-tests.sh

# Start the agent in the background (builds if needed).
# When `pass` is installed and the entry PASS_LLM_ENTRY exists, the LLM
# API key is exported from pass into a temporary file (mode 600) and
# mounted as the llm_api_key compose secret - it never lands in .env,
# `docker inspect`, or the image. Otherwise the secret stays empty and
# the key can be set via .env as before.
# Shared: load the LLM key from pass into a temp file (compose secret).
# Sets KEYFILE (empty when unavailable); caller must clean it up.
define load-llm-key
keyfile=""; \
if command -v pass >/dev/null 2>&1 && pass show $(PASS_LLM_ENTRY) >/dev/null 2>&1; then \
  keyfile="/tmp/thoth-llm-key.$$$$"; \
  pass show $(PASS_LLM_ENTRY) | head -n1 > "$$keyfile"; chmod 600 "$$keyfile"; \
  echo "make: LLM key loaded from pass entry '$(PASS_LLM_ENTRY)'"; \
else \
  echo "make: pass entry '$(PASS_LLM_ENTRY)' not available - starting without key secret"; \
fi
endef

# Shared: load the Mistral key from pass into a temp file (compose secret).
# Sets MISTRAL_KEYFILE (empty when unavailable); caller must clean it up.
define load-mistral-key
mistral_keyfile=""; \
if command -v pass >/dev/null 2>&1 && pass show $(PASS_MISTRAL_ENTRY) >/dev/null 2>&1; then \
  mistral_keyfile="/tmp/thoth-mistral-key.$$$$"; \
  pass show $(PASS_MISTRAL_ENTRY) | head -n1 > "$$mistral_keyfile"; chmod 600 "$$mistral_keyfile"; \
  echo "make: Mistral key loaded from pass entry '$(PASS_MISTRAL_ENTRY)'"; \
else \
  echo "make: pass entry '$(PASS_MISTRAL_ENTRY)' not available - starting without Mistral key secret"; \
fi
endef

up:
	@set -e; \
	$(load-llm-key); \
	$(load-mistral-key); \
	trap 'test -n "$$keyfile" && rm -f "$$keyfile"; test -n "$$mistral_keyfile" && rm -f "$$mistral_keyfile"' EXIT; \
	LLM_API_KEY_FILE="$$keyfile" MISTRAL_API_KEY_FILE="$$mistral_keyfile" \
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) \
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
