# AGENTS.md

Guidance for AI coding agents working on **this repository** (the thoth
agent container). For how the agents inside the container consume
AGENTS.md in *your* projects, see
[docs/agents.md](docs/agents.md#agentsmd-project-instructions).

## Project overview

This repository builds **thoth**, a containerized CLI agent environment:
OpenCode + goose/goosetown + kubectl, with a Prometheus metrics exporter,
a generic skill pack, and Docker Compose wiring. It is intended for
open-source publication - it must contain no private infrastructure
references. The project is maintained and supported by
[jarakube.eu](https://jarakube.eu); the example MCP server
`https://jarakube.eu/mcp` in the docs is an intentional public reference.

## Build and run

- Build requires the host user's uid/gid so bind mounts are writable:
  `make build` (= `HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build`)
- Start: `make up`; shell: `make shell`; one-shot: `make run CMD="opencode --version"`
- Plain `docker compose up` without HOST_UID/HOST_GID produces a
  uid-mismatched image; the entrypoint fails fast with a clear error if
  /workspace is not writable
- The goosetown directory is a git submodule of
  https://github.com/aaif-goose/goosetown - clone with
  `--recurse-submodules`

## Verification

Before committing changes, run what applies:

```bash
bash -n scripts/container-entrypoint.sh        # entrypoint syntax
docker compose config --quiet                  # compose validity (from repo root)
./test-dockerfile.sh                           # Dockerfile sanity checks
make build                                     # full image build (slow)
```

For behavioral changes, verify live: `make up`, then
`docker compose exec -T agent bash -c '...'` (use `-T`; exec with a TTY
can hang in some environments). Check `docker compose logs agent` for the
goosetown clone and MCP registration lines.

## Repository structure

- `Dockerfile` - image: ubuntu 26.04, kubectl 1.36, goose (ARG GOOSE_VERSION),
  opencode from npm (or `build/opencode/opencode` custom binary), goosetown
  tooling copy at `/app/goosetown`
- `scripts/container-entrypoint.sh` - startup: workspace writability check,
  goosetown clone into `$GOOSETOWN_DIR`, example MCP registration, metrics
  exporter
- `docker-compose.yml` / `Makefile` - workspace bind mount, opencode-data
  volume, uid-matched build args
- `skills/` - OpenCode skills bundled into the image; `docs/` - integration
  guides (MCP, other agents)

## Conventions

- Keep all user-generated data on the host filesystem (bind mounts), never
  in anonymous or root-chowned locations. Nothing on the host is ever
  chowned by the container.
- The example MCP server URL `https://jarakube.eu/mcp` is an intentional
  public example; other internal names must not appear anywhere.
- Before publishing or merging, scan for leaks:
  `rg -i "pdr-harbor|happy_bardeen|jarakube-jaraco" --hidden -g '!.git' .`
  Intentional public references that MAY match scans: `jarakube.eu`
  (maintainer/site/MCP example) and the Jaraco GmbH maintainer credit in
  the README. Internal infrastructure names must never appear.
- Docs changes should be verified against the official docs of the tool in
  question; agent CLI facts (flags, config formats, versions) change often.
- Commit messages: conventional style, one line summary + body paragraphs
  (`feat:`, `fix:`, `docs:`, `chore:`).
- Skills use the agent-skills standard: `<name>/SKILL.md` with `name` and
  `description` frontmatter.
