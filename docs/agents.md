# Integrating other agents

This container ships OpenCode and goose/goosetown, but it is a generic
tooling environment: any CLI coding agent that runs on Linux and installs
via npm (or a plain binary) works inside it. This guide shows how to add
the common agents, where each one loads skills and MCP servers from, and
how to map your existing `skills/` directory into them.

The general pattern for every agent:

1. Install it in the running container (or bake it into a derived image).
   Global npm installs need root: `docker compose exec -u root agent npm i -g <pkg>` (or `make shell`, then `sudo`-style `-u root` exec). The container user `appuser` cannot write `/usr/local/lib/node_modules`.
2. Point its skills directory at your skills (bind mount, symlink, or
   copy - see [skills/README.md](../skills/README.md) for the same mapping
   techniques used for OpenCode).
3. Register MCP servers in its config (the example
   [jarakube.eu/mcp](mcp.md) server works with every agent below).

## Quick reference

| Agent | Install | Skills location | MCP config |
|---|---|---|---|
| [OpenCode](https://opencode.ai) | `npm i -g opencode-ai` | `~/.config/opencode/skills/` | `opencode mcp add` |
| [Claude Code](https://code.claude.com/docs) | `npm i -g @anthropic-ai/claude-code` | `~/.claude/skills/` (personal), `.claude/skills/` (project) | `claude mcp add --transport http <name> <url>` |
| [Codex CLI](https://developers.openai.com/codex) | `npm i -g @openai/codex` | `~/.agents/skills/` (user), `.agents/skills/` (repo), `/etc/codex/skills` (admin) | `codex mcp add` / `~/.codex/config.toml` |
| [Gemini CLI](https://geminicli.com/docs) | `npm i -g @google/gemini-cli` | `~/.gemini/skills` | `~/.gemini/settings.json` (`mcpServers`) |
| [goose](https://github.com/aaif-goose/goose) | preinstalled | goosetown skills (see [goosetown](#goose--goosetown-preinstalled)) | `~/.config/goose/config.yaml` (`mcp_servers`) |

All skill formats above use the same core convention: a directory per
skill containing a `SKILL.md` with `name` and `description` frontmatter
(the [agent skills standard](https://agentskills.io)). A skill written
once in this repo's `skills/` format works for OpenCode, Claude Code,
Codex, and Gemini CLI - only the directory it lives in differs.

## Claude Code

Install and verify:

```bash
# as root (appuser cannot write /usr/local/lib/node_modules)
docker compose exec -u root agent npm install -g @anthropic-ai/claude-code

# as appuser
docker compose exec agent claude --version
docker compose exec agent claude /login     # authenticate (Anthropic account or API key)
```

(Verified with Claude Code 2.1.322 in this container.)

### Skills

Claude Code loads personal skills from `~/.claude/skills/` and project
skills from `.claude/skills/` in the working directory. To reuse this
repo's skills:

```bash
# personal skills for all projects
mkdir -p ~/.claude/skills
cp -r /path/to/repo/skills/* ~/.claude/skills/

# or per-project, versioned in git
mkdir -p .claude/skills
cp -r /path/to/repo/skills/ceph .claude/skills/
```

Or bind-mount them at runtime (host paths, no copy):

```bash
docker compose run --rm agent bash -c '
  mkdir -p ~/.claude/skills
  cp -r /workspace/.claude-shared/skills/* ~/.claude/skills/ 2>/dev/null || true
  claude'
```

### MCP servers

```bash
# remote streamable-http server (the example from docs/mcp.md)
claude mcp add --transport http jarakube-website https://jarakube.eu/mcp

# with an auth header
claude mcp add --transport http my-server https://mcp.example.com \
  --header "Authorization: Bearer $MY_TOKEN"

# local stdio server
claude mcp add --env API_KEY=xxx --transport stdio my-tool -- npx -y some-mcp-server

claude mcp list    # verify
```

Config lives in `~/.claude.json` (local scope by default; `--scope user`
for all projects, `--scope project` writes `.mcp.json`).

## Codex CLI

Install and verify (global install needs root, see above):

```bash
docker compose exec -u root agent npm install -g @openai/codex
docker compose exec agent codex --version
docker compose exec agent codex login      # ChatGPT account or API key
```

### Skills

Codex scans (closest first, all loaded in parallel):

- `$CWD/.agents/skills` and parents up to the repo root (repo scope)
- `~/.agents/skills` (user scope - applies to every project)
- `/etc/codex/skills` (admin scope - useful for baking skills into
  derived container images)

```bash
# user-scope skills
mkdir -p ~/.agents/skills
cp -r /path/to/repo/skills/* ~/.agents/skills/

# admin scope inside a derived image (Dockerfile):
# COPY skills/ /etc/codex/skills/
```

### MCP servers

```bash
# stdio server
codex mcp add my-tool -- npx -y some-mcp-server

# verify
codex mcp list
```

Remote (streamable-http) servers go in `~/.codex/config.toml`:

```toml
[mcp_servers.jarakube-website]
url = "https://jarakube.eu/mcp"
```

## Gemini CLI

Install and verify (global install needs root, see above):

```bash
docker compose exec -u root agent npm install -g @google/gemini-cli
docker compose exec agent gemini --version
docker compose exec agent gemini           # OAuth login on first start, or export GEMINI_API_KEY
```

Note: since June 2026 Google points free-tier / Google AI accounts at the
Antigravity CLI; `@google/gemini-cli` remains the open-source CLI for
Gemini Code Assist (Standard/Enterprise) and API-key/Vertex usage.

### Skills

Gemini CLI loads skills from `~/.gemini/skills` (user) and a `.gemini/skills`
directory in the project. Same `SKILL.md` convention:

```bash
mkdir -p ~/.gemini/skills
cp -r /path/to/repo/skills/* ~/.gemini/skills/
```

### MCP servers

`~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "jarakube-website": {
      "httpUrl": "https://jarakube.eu/mcp"
    }
  }
}
```

(`url` is the SSE transport key; `httpUrl` is streamable-http. Recent
versions also have `gemini mcp add`.) Verify with `/mcp` inside a session.

## goose / goosetown (preinstalled)

goose is already installed; goosetown is cloned into the workspace at
`$GOOSETOWN_DIR` (default `/workspace/goosetown`) on first start, and all
goosetown env points there. Its skills live in the clone (goosetown uses
`.claude/skills/` inside its repo for its orchestrator/delegate skills).

Add remote MCP servers to `~/.config/goose/config.yaml`:

```yaml
mcp_servers:
  jarakube-website:
    url: https://jarakube.eu/mcp
```

(The container entrypoint writes this example server automatically - see
[docs/mcp.md](mcp.md).)

## Baking agents into a derived image

For repeatable setups, extend the image instead of installing ad hoc:

```dockerfile
FROM agent-container:latest

# extra agents
RUN npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli

# skills shared by all agents (Codex admin scope; symlink for the others)
COPY skills/ /etc/codex/skills/
RUN mkdir -p /home/appuser/.claude/skills /home/appuser/.agents/skills \
    && ln -sf /etc/codex/skills/* /home/appuser/.claude/skills/ \
    && ln -sf /etc/codex/skills/* /home/appuser/.agents/skills/

# pre-register MCP servers
RUN printf 'mcp_servers:\n  jarakube-website:\n    url: https://jarakube.eu/mcp\n' \
    > /home/appuser/.config/goose/config.yaml
```

Build and run:

```bash
docker build -t my-agent-stack .
docker run --rm -it -v "$(pwd)/workspace:/workspace" my-agent-stack
```

## Authentication notes

- Each agent authenticates independently (OAuth login or API key env
  vars: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, ...).
- OAuth callbacks bind to `localhost` on the host; inside the container
  use API-key auth, or authenticate on the host and mount the agent's
  credentials (the same pattern the README shows for OpenCode's
  `auth.json`).
- Agent credentials live under each agent's home directory
  (`~/.claude`, `~/.codex`, `~/.gemini`). To persist them across
  container restarts, add a compose volume for `~/.agents-credentials`
  style state or mount the whole `~/.config`/dotfiles tree.
