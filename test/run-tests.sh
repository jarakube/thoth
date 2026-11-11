#!/usr/bin/env bash
# Test runner: installs bats if missing, runs the suite.
# Used by `make test` and CI. Runs anywhere with bash + coreutils
# (host, CI runner, or inside the container).

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v bats >/dev/null 2>&1; then
  echo "bats not found - installing to a temp location"
  tmpbin="$(mktemp -d)/bin"
  mkdir -p "$tmpbin"
  if command -v npm >/dev/null 2>&1; then
    # npm bats-core is the quickest cross-platform install
    npm_config_prefix="$(dirname "$tmpbin")" npm install -g bats >/dev/null 2>&1 \
      && export PATH="$(dirname "$tmpbin")/bin:$PATH" \
      || { echo "npm bats install failed"; exit 1; }
  elif command -v apt-get >/dev/null 2>&1 && [ "$(id -u)" = "0" ]; then
    apt-get update -qq && apt-get install -y -qq bats >/dev/null
  else
    echo "install bats manually: https://bats-core.readthedocs.io" >&2
    exit 1
  fi
fi

echo "running bats suite: test/*.bats"
bats test/
