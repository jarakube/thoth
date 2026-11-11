# thoth

![thoth](https://img.shields.io/badge/maintained%20by-jarakube.eu-blue)

Containerized OpenCode agent environment for Kubernetes and Ceph-focused
operations, with Goose/Goosetown multi-agent support and a built-in
Prometheus metrics endpoint for agent runs.

Named after [Thoth](https://en.wikipedia.org/wiki/Thoth), the ancient
Egyptian deity of wisdom, writing, and knowledge.

## Project purpose

This repository builds a CLI agent image that combines:

- [OpenCode](https://opencode.ai) (`opencode-ai`) for interactive coding/ops workflows
- [Goose](https://github.com/aaif-goose/goose) + [Goosetown](https://github.com/aaif-goose/goosetown) for multi-agent orchestration
- `kubectl` for Kubernetes cluster access
- A small, generic skill pack (currently a Ceph expert skill)

The result is a ready-to-run agent container for infrastructure-heavy tasks
where Kubernetes and storage knowledge are needed in the same environment.

## Maintainer and support

This project is maintained and supported by
**[jarakube.eu](https://jarakube.eu)** - the sovereign Kubernetes platform
by [Jaraco GmbH](https://www.jaraco.de).

- Issues, feature requests, and contributions are welcome via GitHub.
- Commercial support, hosting, and platform integrations are available
  through jarakube.eu.
- The example MCP server used in the docs
  ([jarakube.eu/mcp](https://jarakube.eu/mcp)) is operated by the same
  platform.

## What the image contains

| Component | Location in container | Notes |
|-----------|----------------------|-------|
| OpenCode | `/usr/local/bin/opencode` | Installed from npm (`opencode-ai@latest`) by default; see below for custom builds |
| Goose | `/usr/local/bin/goose` | Pinned via `ARG GOOSE_VERSION` (default `v1.50.0`) |
| Goosetown | `/app/goosetown` | Public [aaif-goose/goosetown](https://github.com/aaif-goose/goosetown) git submodule |
| kubectl | `/usr/local/bin/kubectl` | v1.36 from pkgs.k8s.io |
| Skills | `/home/appuser/.config/opencode/skills/` | Everything from repo `skills/` directory |
| Metrics exporter | `/app/scripts/opencode-prometheus-exporter.py` | Listens on `:9464` |
| gh CLI | `/usr/bin/gh` | For GitHub workflows from inside the container |

### Use a custom opencode build

By default the image installs the official `opencode-ai` release from npm. To
use your own opencode build (e.g. a patched fork):

1. Build the binary (see the [opencode repo](https://github.com/sst/opencode));
   for the Keycloak-enabled fork use
   [jaracogmbh/opencode, branch `feature/34733/keycloak-sso-token-expiry-issue`](https://github.com/jaracogmbh/opencode/tree/feature/34733/keycloak-sso-token-expiry-issue)
   (see [Configure OpenCode to use Keycloak](#configure-opencode-to-use-keycloak)):
   ```bash
   git clone --branch feature/34733/keycloak-sso-token-expiry-issue \
     https://github.com/jaracogmbh/opencode.git
   cd opencode
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
cd thoth
docker build -t thoth .
```

Run interactively:

```bash
docker run --rm -it thoth
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
- All user-generated data stays on the **host filesystem**: workspace and
  per-run metrics (`./share/opencode-runs/`) are bind mounts you can inspect
  directly
- A **goosetown working clone** is created at `workspace/goosetown` on first
  start (host-visible), and all goosetown env (`GOOSETOWN_DIR`, `GUIDES_DIR`,
  `PLANS_DIR`, `RESEARCH_DIR`, `WORK_LOGS_DIR`) points into it. Override with
  `GOOSETOWN_DIR`/`GOOSETOWN_REPO_URL`/`GOOSETOWN_REF` to use your own fork
  or an existing clone
- `opencode auth login` state persists in the `opencode-data` named volume
  across restarts (kept out of the project dir since it holds credentials)
- Prometheus metrics at `http://localhost:9464/metrics`
- One-shot sessions: `make run CMD="opencode"` or
  `docker compose run --rm thoth opencode`

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
  thoth
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
  - job_name: thoth
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
  thoth
```

## Goose / Goosetown

The image also ships [Goose](https://github.com/aaif-goose/goose) and the
[Goosetown](https://github.com/aaif-goose/goosetown) multi-agent framework:

```bash
# interactive goose session
goose session

# goosetown orchestrator (alias: gt)
goose load source:goosetown-orchestrator

# goose backed by a LiteLLM proxy
goose-litellm session "Analyze this codebase"
```

Details:

- [LITELLM_CONFIGURATION.md](LITELLM_CONFIGURATION.md) - configuring the
  agents against a LiteLLM proxy: goose via the `goose-litellm` wrapper,
  OpenCode via a custom `openai-compatible` provider (OpenCode has no
  native litellm provider - it connects to LiteLLM's OpenAI-compatible API)
- [GOOSETOWN_INTEGRATION.md](GOOSETOWN_INTEGRATION.md) - what the image sets
  up for goosetown (paths, wrappers, telepathy)
- `configure-goose.sh` - helper to drive `goose configure` non-interactively
  inside a running container (`CONTAINER=<name> ./configure-goose.sh`)

### One config for both agents

OpenCode and goose need the same data to reach an LLM endpoint (URL, API
key, model list) but store it differently. `scripts/sync-llm-config.sh`
keeps them in sync from a **single source of truth** - the `LLM_*`
environment variables - and runs automatically at container start:

```bash
# .env - configure once, both agents follow
LLM_ENDPOINT=http://litellm-proxy:4000/v1   # includes /v1
LLM_MODELS=mistral-small-latest mistral-large-latest
CUSTOM_LITELLM_API_KEY=sk-...
```

```bash
# apply and verify
docker compose up -d
docker compose exec thoth opencode models litellm   # OpenCode: litellm/<model> entries
docker compose exec thoth goose doctor               # goose: "new session · litellm <model>"
```

The script writes the OpenCode custom provider config
(`~/.config/opencode/opencode.json`), the goose provider selection
(`~/.config/goose/config.yaml`, using goose's built-in `litellm`
provider), and the shared `LITELLM_*` env for goose sessions. Unset
`LLM_ENDPOINT` = no-op; each agent falls back to its own configuration.
After changing `LLM_*` in `.env`, restart with `docker compose up -d` to
re-run the sync. See [LITELLM_CONFIGURATION.md](LITELLM_CONFIGURATION.md)
for the full variable reference.

### Keeping the API key out of .env (pass / compose secrets)

The key never needs to live in `.env` or the compose file. Three options:

1. **`pass` (recommended)** - store the key in the standard Unix password
   store and let `make up` wire it in:

   ```bash
   pass init <your-gpg-id>
   pass insert -m llm/thoth-api-key    # paste the key

   make up    # exports the key from pass into the llm_api_key compose secret
   ```

   The Makefile resolves `PASS_LLM_ENTRY` (default `llm/thoth-api-key`)
   into a temporary mode-600 file, mounts it as the `llm_api_key` docker
   compose secret, and deletes the file afterwards. Without pass or the
   entry, `make up` starts without the secret and falls back to `.env`.

2. **Compose secret via any secret manager** - point `LLM_API_KEY_FILE`
   in `.env` at a file containing the key (sops, vault, 1password CLI,
   plain file - your choice). The file is mounted read-only at
   `/run/secrets/llm_api_key`.

3. **Plain env var** - `CUSTOM_LITELLM_API_KEY` in `.env` (simplest, but
   visible in `docker inspect` and shell history).

In all cases the sync script reads the key from the env var or the
secret file and exports it for the agents - it is never written to any
generated config file (configs only reference the variable).

Goosetown runs as a **working clone inside the workspace**: the container
entrypoint clones `https://github.com/aaif-goose/goosetown.git` to
`workspace/goosetown` on first start (skipped if the directory already
exists), and points `GOOSETOWN_DIR`, `GUIDES_DIR`, `PLANS_DIR`,
`RESEARCH_DIR` and `WORK_LOGS_DIR` at it. Its working dirs live inside the
clone (upstream gitignores them), so everything the orchestrator produces
persists on the host through the workspace bind mount. Use your own fork via
`GOOSETOWN_REPO_URL`/`GOOSETOWN_REF`, or point `GOOSETOWN_DIR` at an existing
clone. The image also carries a tooling copy at `/app/goosetown` used as
fallback for the `goose` telepathy wrapper.

## CI

`.github/workflows/build.yml` builds the image on every push to `main`
and publishes it to `ghcr.io/<owner>/thoth` using the default
`GITHUB_TOKEN`. No private registries or secrets are required. Published
images are also scanned with Trivy (fail on CRITICAL/HIGH findings,
unfixed only); the scan runs on every push, not on pull requests.

## Configure OpenCode to use Keycloak

> **Note: this requires a custom OpenCode build.** The stock
> `opencode-ai` release installed by default (via npm) does not include
> the Keycloak authentication feature - `auth.keycloak` config and
> `opencode auth login keycloak` come from a patched OpenCode fork. The
> reference fork with the Keycloak patches is
> [jaracogmbh/opencode (branch `feature/34733/keycloak-sso-token-expiry-issue`)](https://github.com/jaracogmbh/opencode/tree/feature/34733/keycloak-sso-token-expiry-issue).
> Clone that branch, build the binary, and place it at
> `build/opencode/opencode` before building the image (see
> [Use a custom opencode build](#use-a-custom-opencode-build)); the
> Dockerfile then uses it instead of the npm release. With the stock
> npm release, this section does not apply.

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
     thoth
   ```

   This is the recommended path because the default Keycloak callback binds
   to `127.0.0.1:19877`, which is straightforward on the host but awkward from
   inside Docker.

4. Verify the stored identity.

   ```bash
   opencode auth list
   ```

## MCP servers

Both agents support remote MCP servers (streamable-http). On first start the
container registers a public example server, `https://jarakube.eu/mcp`
(Jaraco website content: services, blog posts, categories, Jarakube
resources), with **both** OpenCode and goose. Opt out with
`MCP_EXAMPLE_ENABLED=0`, or override name/URL via `MCP_EXAMPLE_NAME` /
`MCP_EXAMPLE_URL`.

Verify:

```bash
opencode mcp list    # shows jarakube-website (connected)
```

See [docs/mcp.md](docs/mcp.md) for adding your own servers to either agent.

## Integrating other agents

The container is a generic environment for CLI coding agents - Claude Code,
Codex CLI, and Gemini CLI install via npm and run alongside OpenCode and
goose. All of them share the same skill format (`SKILL.md` with
name/description frontmatter), so this repo's `skills/` directory maps into
each one; MCP servers are configured per agent.

See [docs/agents.md](docs/agents.md) for install commands, skills
locations, MCP config formats, derived-image recipes, and authentication
notes per agent.

## Use your GPG keys

To sign commits (or use `pass` with your existing keys) inside the
container, there are two supported ways to reuse your host keys:

### Option A: mount the host keyring

Comment out the `gnupg-data` volume line in `docker-compose.yml` and
mount the host keyring at the same path instead:

```yaml
volumes:
  # - gnupg-data:/home/appuser/.gnupg      # container-local (default)
  - ${HOME}/.gnupg:/home/appuser/.gnupg    # host keyring
```

GnuPG keeps daemon state (sockets, lock files) in its home directory, and
that state does not survive bind mounts - a host `S.keyboxd` socket is a
dead file inside the container, which makes gpg fail with
`can't connect to keyboxd` or hang on stale locks. The container
entrypoint detects and removes dead sockets and stale cross-machine lock
files at startup, so the container-side daemons (`keyboxd`, `gpg-agent`)
launch cleanly with the mounted keyring.

Notes:

- The mount is read-write; gpg needs to create its sockets and update
  trustdb inside the directory.
- Do not run gpg on the host and in the container simultaneously against
  the same keyring - the daemons would fight over locks. Not recommended
  on Docker Desktop for Mac (VirtioFS degrades sockets further); use
  option B there.
- Requires the uid match (the image is built with your uid via
  `make up`).

### Option B: import a key export (recommended, works everywhere)

Export the secret key on the host and import it at container start:

```bash
# host: armored export of your key (prompts for the passphrase)
gpg --armor --export-secret-keys YOURKEYID > ~/thoth-gpg-key.asc
```

```yaml
# docker-compose.yml
volumes:
  # host path (left side) ──► container path (right side)
  - ${HOME}/thoth-gpg-key.asc:/home/appuser/gpg-key.asc:ro
environment:
  # GPG_IMPORT_FILE must be the CONTAINER path - the right side of the
  # volume mount - because the entrypoint reads it inside the container
  GPG_IMPORT_FILE: /home/appuser/gpg-key.asc
  # optional: mark imported keys as ultimately trusted
  # GPG_TRUST_IMPORTED: "1"
```

The entrypoint imports the key into the container's `~/.gnupg`, which is
persisted in the `gnupg-data` named volume - the key survives container
restarts. The import runs on every start and is idempotent (gpg
de-duplicates), so keep the export file mounted; rotate it on the host
and the container picks up the new key on the next start. No daemon state
is shared with the host, so this works on every platform (including
Docker Desktop for Mac).

Keep the export file mounted: if `GPG_IMPORT_FILE` points at a path that
is not mounted into the container, the entrypoint logs a warning and no
key is imported.

Verify inside the container:

```bash
docker compose exec thoth gpg -k          # lists your key (not just "trustdb created")
docker compose exec thoth gpg --list-secret-keys
```

> If `gpg -k` only prints `trustdb created` and no key block, the import
> did not happen: check `docker compose logs thoth` for the
> `gpg: imported keys from ...` line or the missing-mount warning.

### Complete example configuration

Option B end to end - host export, compose wiring, git signing, and
optional `pass` use:

```bash
# 1. host: export your key (armored, prompts for the passphrase)
gpg --armor --export-secret-keys YOURKEYID > ~/thoth-gpg-key.asc
```

```yaml
# 2. .env
GPG_IMPORT_FILE=/home/appuser/gpg-key.asc
GPG_TRUST_IMPORTED=1        # optional: ultimate ownertrust for the key
```

```yaml
# 3. docker-compose.yml
services:
  thoth:
    volumes:
      - gnupg-data:/home/appuser/.gnupg                 # default: persisted keyring
      - ${HOME}/thoth-gpg-key.asc:/home/appuser/gpg-key.asc:ro
```

```bash
# 4. start and verify
make up
docker compose logs thoth | grep gpg
#   gpg: imported keys from /home/appuser/gpg-key.asc
#   gpg: git signing configured (user.signingkey=..., commit.gpgsign=true)
docker compose exec thoth gpg -k
```

What the entrypoint configures automatically after the import:

- **git commit signing**: when exactly one secret key is present,
  `user.signingkey` is set to its fingerprint and `commit.gpgsign` /
  `tag.gpgsign` are enabled - every `git commit` and `git tag` inside the
  container is signed. With multiple keys nothing is guessed; set
  `git config --global user.signingkey <fpr>` yourself.
- The git identity (`user.email`/`user.name`) stays the image default
  (`agent@example.com` / `agent`) - override it to match the key's uid:
  ```bash
  docker compose exec thoth git config --global user.email "you@example.com"
  docker compose exec thoth git config --global user.name "Your Name"
  ```
  or set it in `.gitconfig` and mount it over `/home/appuser/.gitconfig`.

Note on `pass`: the password store lives on the **host** - this design
uses it only from there (see
[Keeping the API key out of .env](#keeping-the-api-key-out-of-env-pass--compose-secrets),
where `make up` reads the LLM key from the host's pass store). `pass` is
not installed inside the container; if you need secrets from the host
store during a session, mount the store read-only
(`- ${HOME}/.password-store:/home/appuser/.password-store:ro`) and read
the entries with `gpg -d`, or pass values in as environment variables.

## Network monitoring (Suricata, opt-in)

A Suricata IDS sidecar can passively monitor the agent's network traffic
- every LLM API call, DNS lookup, and egress connection the agents make
- without touching the application or routing traffic through a proxy.
It shares thoth's network namespace and writes structured EVE JSON
events (flow, dns, tls, http, alert, stats) to `suricata/logs/eve.json`.

```bash
make suricata-init    # validate the versioned sensor config
make suricata-up      # start thoth + the suricata sidecar
make suricata-down    # stop both (logs persist in suricata/logs/)

# inspect what the agents have been talking to
jq -r 'select(.event_type == "tls") | .tls.sni // empty' suricata/logs/eve.json | sort -u
jq -r 'select(.event_type == "flow") | [.src_ip, .dest_ip, .dest_port] | @tsv' suricata/logs/eve.json | tail -20
```

The sensor configuration (`suricata/config/suricata.yaml`) is
version-controlled and reviewed - no generated state. Detection rules
are OFF by default (`rule-files: []`): without signatures you get
flow/dns/tls/http/stats events but no alerts; enable rules with
`suricata-update` inside the running sidecar and add them to
`rule-files` (see the
[suricata-update docs](https://docs.suricata.io/en/latest/rule-management/suricata-update.html)).

Caveats worth knowing (full reference:
[docs/suricata-docker-compose-integration.md](docs/suricata-docker-compose-integration.md)):

- **Passive IDS, not a firewall** - it observes; it never blocks.
- **DNS blind spot**: Docker's embedded resolver answers on loopback
  (`127.0.0.11`), which `eth0` capture does not see - many DNS queries
  will be invisible.
- **`depends_on` is not sensor readiness** - traffic from thoth's
  startup may be missed; restart the sidecar for a clean capture window.
- The sidecar adds `NET_ADMIN`/`NET_RAW`/`SYS_NICE` capabilities - a
  real privilege grant, which is why it is opt-in and never part of
  plain `make up`.
- Log retention: `eve.json` grows indefinitely; rotate or ship to a
  SIEM before long-running deployments.

## Repository notes

- [llms.txt](llms.txt) / [llms-full.txt](llms-full.txt): documentation
  index and full flattened docs for LLM consumption (per
  [llmstxt.org](https://llmstxt.org)) - regenerate both when docs change.
- Every commit must be signed off (DCO): commit with
  `git commit --signoff`, producing a `Signed-off-by: Name <email>`
  trailer matching the commit author. CI rejects unsigned commits.
- PR jobs are gated: both the Test (unit tests) and Build (image)
  workflows run on a PR only after the repository owner comments
  `ready for test` on it. The approval is per-commit state: pushing new
  commits to the PR invalidates it, and the owner must comment
  `ready for test` again. Pushes to `main` always run.
- Add new skills under `skills/<name>/SKILL.md`; they will be copied into the
  image on build. See [skills/README.md](skills/README.md).
- The goosetown directory is a git submodule: clone with
  `--recurse-submodules` and update with `git submodule update --remote`.
- Review any local credential or key material before publishing images or
  sharing this repository.
