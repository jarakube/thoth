# agent-container

Containerized OpenCode agent environment for Kubernetes and Ceph-focused
operations, with Goose/Goosetown multi-agent support and a built-in
Prometheus metrics endpoint for agent runs.

## Project purpose

This repository builds a CLI agent image that combines:

- [OpenCode](https://opencode.ai) (`opencode-ai`) for interactive coding/ops workflows
- [Goose](https://github.com/aaif-goose/goose) + [Goosetown](https://github.com/block/goosetown) for multi-agent orchestration
- `kubectl` for Kubernetes cluster access
- A small, generic skill pack (currently a Ceph expert skill)

The result is a ready-to-run agent container for infrastructure-heavy tasks
where Kubernetes and storage knowledge are needed in the same environment.

## What the image contains

| Component | Location in container | Notes |
|-----------|----------------------|-------|
| OpenCode | `/usr/local/bin/opencode` | Installed from npm (`opencode-ai@latest`) by default; see below for custom builds |
| Goose | `/usr/local/bin/goose` | Pinned via `ARG GOOSE_VERSION` (default `v1.50.0`) |
| Goosetown | `/app/goosetown` | Public [block/goosetown](https://github.com/block/goosetown) git submodule |
| kubectl | `/usr/local/bin/kubectl` | v1.36 from pkgs.k8s.io |
| Skills | `/home/appuser/.config/opencode/skills/` | Everything from repo `skills/` directory |
| Metrics exporter | `/app/scripts/opencode-prometheus-exporter.py` | Listens on `:9464` |
| gh CLI | `/usr/bin/gh` | For GitHub workflows from inside the container |

### Use a custom opencode build

By default the image installs the official `opencode-ai` release from npm. To
use your own opencode build (e.g. a patched fork):

1. Build the binary (see the [opencode repo](https://github.com/sst/opencode)):
   ```bash
   bun install && bun run build --single
   ```
2. Place it at `build/opencode/opencode` in the repository root.
3. In the `Dockerfile`, comment the `npm install -g opencode-ai@latest` line
   and uncomment the `COPY build/opencode/opencode ...` line.
4. `docker build` as usual.

## Build and run

Build:

```bash
git clone --recurse-submodules <this-repo-url>
cd agent-container
docker build -t agent .
```

Run interactively:

```bash
docker run --rm -it agent
```

### Docker Compose (recommended)

The easiest way to run the container. User-generated data stays on the host
filesystem; only OpenCode auth/session state lives in a named volume:

```bash
cp .env.example .env   # optional: add provider keys, set WORKSPACE_DIR
make up                # = HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose up -d --build
make shell             # interactive bash in /workspace
```

- The agent lands in `/workspace` (defaults to `./workspace/`, override with
  `WORKSPACE_DIR` in `.env`)
- All user-generated data stays on the **host filesystem**: workspace,
  goosetown working dirs (`./goosetown-data/`), and per-run metrics
  (`./share/opencode-runs/`) are bind mounts you can inspect directly
- `opencode auth login` state persists in the `opencode-data` named volume
  across restarts (kept out of the project dir since it holds credentials)
- Prometheus metrics at `http://localhost:9464/metrics`
- One-shot sessions: `make run CMD="opencode"` or
  `docker compose run --rm agent opencode`

Permissions: the image builds `appuser` with your host uid/gid
(`APP_UID`/`APP_GID` build args; `make` passes them automatically, plain
`docker compose` reads `HOST_UID`/`HOST_GID` from `.env` or the
environment). Host bind-mount directories must exist and be writable by
that uid - the defaults ship `.gitkeep` files so they exist with your
ownership after clone. Nothing on the host is ever chowned by compose or
the container.

If you need cluster access, mount your kubeconfig (uncomment the line in
`docker-compose.yml`):

```yaml
volumes:
  - ${HOME}/.kube:/home/appuser/.kube:ro
```

With the metrics endpoint exposed (plain docker):

```bash
docker run --rm -it \
  -p 9464:9464 \
  -v "$(pwd):/app" \
  -v "$HOME/.local/share/opencode/auth.json:/home/appuser/.local/share/opencode/auth.json:ro" \
  agent
```

Then scrape:

```bash
curl http://127.0.0.1:9464/metrics
```

## Per-run OpenCode metrics

Use `./scripts/opencode-run-with-metrics.sh` when you need session-scoped token
and cost reporting instead of global `opencode stats` output.

Example:

```bash
./scripts/opencode-run-with-metrics.sh \
  --metrics-dir share/opencode-runs \
  --title-prefix blogpost-ci \
  -- --model openai/gpt-5.4 "Reply with exactly OK"
```

The wrapper:

- creates a unique run title
- runs `opencode run --format json`
- captures the emitted `sessionID`
- exports that exact session with `opencode export`
- writes raw events, stderr logs, the exported session, and `run-metrics.json`
  under `share/opencode-runs/<run-title>/`

This avoids mixing usage across multiple sessions or projects and is a better
fit for CI reporting.

## Prometheus endpoint

The container starts a lightweight Prometheus exporter on `:9464` by default
and exposes `/metrics`.

The exporter reads the per-run artifacts under `share/opencode-runs/` and
publishes aggregated metrics such as:

- `opencode_runs_total`
- `opencode_run_duration_seconds_total`
- `opencode_tokens_total{token_kind=...}`
- `opencode_cost_usd_total`
- `opencode_messages_total{role=...}`
- `opencode_tool_calls_total{tool=...,status=...}`
- `opencode_step_finishes_total{reason=...}`
- `opencode_log_events_total{service=...,status=...,event_type=...}`
- `opencode_log_tool_failures_total{tool=...,kind=...}`
- `opencode_log_errors_total{kind=...}`

Configuration:

- `OPENCODE_METRICS_ENABLED=0` disables the exporter
- `OPENCODE_METRICS_HOST` sets the listen address
- `OPENCODE_METRICS_PORT` sets the listen port
- `OPENCODE_RUN_METRICS_DIR` sets the run artifact directory used by both the
  wrapper and exporter

Minimal Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: agent-container
    static_configs:
      - targets:
          - localhost:9464
```

## Skills

See [skills/README.md](skills/README.md) for the full documentation of the
skill system, including how to add your own skills and how to **map skills
into the container at runtime** (bind mount, volume, ConfigMap, PVC, derived
image, or git clone) instead of bundling them into the image.

Quick summary:

```bash
# development: mount host skills over the bundled ones
docker run --rm -it \
  -v "$(pwd)/my-skills:/home/appuser/.config/opencode/skills:ro" \
  agent
```

## Goose / Goosetown

The image also ships [Goose](https://github.com/aaif-goose/goose) and the
[Goosetown](https://github.com/block/goosetown) multi-agent framework:

```bash
# interactive goose session
goose session

# goosetown orchestrator (alias: gt)
goose load source:goosetown-orchestrator

# goose backed by a LiteLLM proxy
goose-litellm session "Analyze this codebase"
```

Details:

- [LITELLM_CONFIGURATION.md](LITELLM_CONFIGURATION.md) - configuring goose
  against a LiteLLM proxy (provider/model env vars, fallbacks, Ollama)
- [GOOSETOWN_INTEGRATION.md](GOOSETOWN_INTEGRATION.md) - what the image sets
  up for goosetown (paths, wrappers, telepathy)
- `configure-goose.sh` - helper to drive `goose configure` non-interactively
  inside a running container (`CONTAINER=<name> ./configure-goose.sh`)

To persist goosetown working directories (GUIDES, PLANS, RESEARCH, WORK_LOGS)
across container restarts, set `GOOSETOWN_DATA_DIR` to a mounted volume path;
the entrypoint relocates the directories under `<path>/goosetown/`.

## CI

`.github/workflows/build.yml` builds the image on every push to `main` and
publishes it to `ghcr.io/<owner>/agent` using the default `GITHUB_TOKEN`.
No private registries or secrets are required.

## Configure OpenCode to use Keycloak

OpenCode in this image supports a global Keycloak login plus MCP server
configs that reuse that bearer token.

1. Add Keycloak defaults to your OpenCode config.

   Use either a project config like `.opencode/opencode.jsonc` or a global
   config like `~/.config/opencode/opencode.jsonc`:

   ```jsonc
   {
     "auth": {
       "keycloak": {
         "issuer": "https://sso.example.com/realms/my-realm",
         "clientId": "opencode-cli",
         "scope": "openid profile email offline_access"
       }
     },
     "mcp": {
       "jira": {
         "type": "remote",
         "url": "https://mcp.example.com",
         "auth": {
           "type": "bearer",
           "provider": "keycloak"
         }
       }
     }
   }
   ```

   You can also provide the Keycloak defaults through environment variables:

   - `OPENCODE_KEYCLOAK_ISSUER`
   - `OPENCODE_KEYCLOAK_CLIENT_ID`
   - `OPENCODE_KEYCLOAK_CLIENT_SECRET`
   - `OPENCODE_KEYCLOAK_SCOPE`
   - `OPENCODE_KEYCLOAK_REDIRECT_URI`

2. Log into Keycloak once.

   ```bash
   opencode auth login keycloak
   ```

   This stores the session in `~/.local/share/opencode/auth.json`.

3. Reuse that login inside the container.

   The simplest workflow is to authenticate on the host, then mount the auth
   file into the container:

   ```bash
   docker run --rm -it \
     -v "$HOME/.local/share/opencode/auth.json:/home/appuser/.local/share/opencode/auth.json:ro" \
     -v "$HOME/.config/opencode:/home/appuser/.config/opencode:ro" \
     agent
   ```

   This is the recommended path because the default Keycloak callback binds
   to `127.0.0.1:19877`, which is straightforward on the host but awkward from
   inside Docker.

4. Verify the stored identity.

   ```bash
   opencode auth list
   ```

## Repository notes

- Add new skills under `skills/<name>/SKILL.md`; they will be copied into the
  image on build. See [skills/README.md](skills/README.md).
- The goosetown directory is a git submodule: clone with
  `--recurse-submodules` and update with `git submodule update --remote`.
- Review any local credential or key material before publishing images or
  sharing this repository.
