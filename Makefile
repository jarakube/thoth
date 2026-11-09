# Convenience wrapper around docker compose.
# Passes the host user's uid/gid so the in-container appuser matches the
# host user and bind mounts are writable without any chown.

HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

.PHONY: up down build shell run logs ps clean

# Start the agent in the background (builds if needed)
up:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) docker compose up -d --build

# Stop the agent (volumes and host bind mounts are preserved)
down:
	docker compose down

# Build the image with the host user's uid/gid
build:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) docker compose build

# Interactive shell in the running agent
shell:
	docker compose exec agent bash

# One-shot: docker compose run --rm agent <CMD...>
# Usage: make run CMD="opencode --version"
run:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) docker compose run --rm agent $(CMD)

logs:
	docker compose logs -f agent

ps:
	docker compose ps

# Remove containers AND the opencode-data named volume.
# Host bind mounts (workspace/, goosetown-data/, share/opencode-runs/) are
# never touched.
clean:
	docker compose down -v
