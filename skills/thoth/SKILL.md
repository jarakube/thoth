---
name: thoth
description: Develop and test the thoth agent container itself - entrypoint/sync scripts, compose wiring, tests, docs, CI gates. Use when working on this repository (scripts/, docker-compose.yml, Dockerfile, test/, workflows). Covers the in-container constraint that docker is unavailable and how to verify changes directly inside the running container.
---

# thoth developer skill

You are working on **thoth** - the containerized agent environment
(OpenCode + goose/goosetown + kubectl) maintained by jarakube.eu. This
skill covers how to change, test, and document this repository.

## Critical constraint: docker is NOT available inside the container

If you are running INSIDE the thoth container (check: `ls
/var/run/docker.sock` fails and `command -v docker` finds nothing),
there is no docker CLI and no docker socket. You cannot build images,
start the compose stack, or run docker-based tests from in here.

What this means in practice:

- **Changes can be made inside the container directly for tests**: the
  repository is reachable through the workspace mount (`/workspace`)
  or the scripts at `/app/scripts/`. Edit files, run them, observe
  behavior - no rebuild needed.
- Scripts under test run in-place: `bash /app/scripts/sync-llm-config.sh`
  writes to `~/.config/...` of the current user - inspect the generated
  configs directly to verify behavior.
- For anything that needs a REBUILD (Dockerfile changes, entrypoint
  changes used at container start), make the change, verify what you
  can in-place, and note that the full verification (`make up`) must
  happen on the HOST - hand the change off with that instruction.
- Docker-dependent tests (`test/block-egress.bats`, suricata compose
  tests in `test/entrypoint.bats`) cannot run inside; the docker-free
  suite (`test/sync-llm-config.bats`) can. Verified workflow inside
  the container:

  ```bash
  # 1. bats via a USER npm prefix (global installs need root):
  npm config set prefix ~/.npm-global
  npm install -g bats
  export PATH="$PATH:~/.npm-global/bin"

  # 2. the repo: your working copy if you mounted it into /workspace,
  #    otherwise clone it (git + gh are available):
  cd /workspace && git clone https://github.com/jarakube/thoth.git

  # 3. run the docker-free suite (tests are hermetic: they unset LLM_*
  #    so the container's own env wiring does not leak in):
  cd thoth && bats test/sync-llm-config.bats
  ```

## Repository layout (what you will touch)

| Path | Purpose |
|---|---|
| `scripts/container-entrypoint.sh` | Container startup: workspace guard, LLM key resolution, GPG setup, beads init, MCP registration. Functions + `main()` behind a source guard - unit tests source it. |
| `scripts/sync-llm-config.sh` | Single-source LLM config for OpenCode + goose (`LLM_*` env vars -> both agents' configs). |
| `scripts/block-egress.sh` + `block-egress-ns.sh` | Egress blocking (iptables `thoth-block` rules in thoth's namespace). |
| `scripts/init-suricata.sh`, `suricata-report.sh` | Suricata sidecar init + traffic overview report. |
| `docker-compose.yml` | Base stack: workspace bind mount, volumes (opencode-data, gnupg-data, beads-data), LLM_*/GPG_*/BEADS_* env wiring. |
| `docker-compose.suricata.yml` | Opt-in IDS sidecar override (never part of plain `make up`). |
| `Dockerfile` | ubuntu:26.04, kubectl, goose (ARG GOOSE_VERSION), opencode from npm, uid-matched appuser (APP_UID/APP_GID). |
| `test/*.bats` | Unit/integration tests; `test/run-tests.sh` installs bats if missing. |
| `.github/workflows/` | build.yml (owner-gated image builds + Trivy), test.yml (gated bats+shellcheck), dco.yml, ready-for-test.yml. |

## Conventions (enforced by CI)

- **DCO**: every commit needs `Signed-off-by: Name <email>` matching
  the author - commit with `git commit --signoff`.
- **Commit style**: conventional one-liners (`feat:`, `fix:`, `docs:`,
  `chore:`) with a body explaining what and why.
- **Docs sync**: after changing README/docs, regenerate `llms.txt`
  (curated index) and `llms-full.txt` (flattened) - see AGENTS.md.
- **No internal names**: only jarakube.eu (maintainer, example MCP
  server) may appear; scan before publishing:
  `rg -i "pdr-harbor|happy_bardeen|jarakube-jaraco" --hidden -g '!.git' .`
- **Host data stays on the host**: user data lives in bind mounts
  (workspace/, share/opencode-runs/) - never chown host files from
  the container.
- **shellcheck** (error severity) over `scripts/*.sh` and
  `test/run-tests.sh` runs in CI - keep scripts clean.

## Making and verifying a change (in-container workflow)

1. **Edit** the file in `/workspace` (the repo) - changes are
   immediately visible on the host through the bind mount.
2. **Targeted verification** - run the touched component directly:

   ```bash
   # entrypoint logic (functions are sourceable):
   bash -c 'source scripts/container-entrypoint.sh; gpg_clean_dead_daemon_state /tmp/test-gnupg'

   # sync script against a scratch HOME:
   HOME=/tmp/synchome LLM_ENDPOINT=http://x:4000/v1 bash scripts/sync-llm-config.sh
   jq . /tmp/synchome/.config/opencode/opencode.json
   ```

3. **Docker-free unit tests** (see above) for the touched area.
4. **Commit** with `git commit --signoff` (git works inside: the
   workspace is a git checkout; GPG signing is configured if a key was
   imported - see the README GPG section).
5. Note in the commit/PR what needs host-side verification (rebuild,
   compose lifecycle, docker-based tests).

## CI flow (what happens to your change on the host)

- PRs: Test workflow (bats + shellcheck) and Build workflow (image
  build) run only after the repo owner comments `ready for test` on
  the PR; new commits invalidate the approval. DCO checks every commit.
- main: builds + Trivy scan (CRITICAL/HIGH, unfixed-only) always run;
  images publish to ghcr.io/<owner>/thoth.

## Common pitfalls in this repo

- **Entrypoint exports do not reach `docker compose exec` shells** -
  non-interactive exec bypasses PID 1; that is why generated configs
  embed values and `.bashrc` hooks exist. Do not "fix" this by
  re-exporting in scripts; extend the generated files instead.
- **Fresh named volumes are root-owned** unless the image contains the
  mount path (see gnupg-data/beads-data seeding in the Dockerfile).
  New volume mounts need the path created in the image first.
- **jq argument context**: inside `group_by(f(x))`, `x` is evaluated
  against the ARRAY, not the element - bind explicitly
  (`group_by(. as $e | ...)`).
- **Heredoc terminators** must be column-0; indented terminators break
  bash scripts silently.
- **`bd init` takes no path argument** - it operates on CWD/BEADS_DIR.
- **PTID/PGID remap in the suricata image** only happens with
  SYS_NICE+NET_ADMIN capabilities present.

## Quick reference (host-side, for handoff notes)

```bash
make up                 # start thoth (uid-matched build, pass key)
make test               # full bats suite (host)
make suricata-up        # thoth + IDS sidecar
make block-egress ARGS="add <ip|domain>"
make suricata-report    # traffic overview
```
