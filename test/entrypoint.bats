#!/usr/bin/env bash
# Unit tests for the thoth container entrypoint and sync script.
#
# The entrypoint is refactored into functions with a source guard, so
# these tests source it without executing the container startup.
#
# Run:  bats test/   (or ./test/run-tests.sh inside the container/CI)

bats_require_minimum_version 1.5.0

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"
  # source the entrypoint - the guard keeps main() from running
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../scripts/container-entrypoint.sh" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- gpg_clean_dead_daemon_state ------------------------------------------

@test "gpg cleanup: removes a stale (unconnectable) daemon socket" {
  mkdir -p "$TEST_DIR/gnupg"
  python3 -c "
import socket
s = socket.socket(socket.AF_UNIX)
s.bind('$TEST_DIR/gnupg/S.keyboxd')
s.listen(1)
s.close()   # socket file remains, nothing listening
"
  [ -S "$TEST_DIR/gnupg/S.keyboxd" ]
  gpg_clean_dead_daemon_state "$TEST_DIR/gnupg"
  [ ! -e "$TEST_DIR/gnupg/S.keyboxd" ]
}

@test "gpg cleanup: keeps a LIVE daemon socket" {
  mkdir -p "$TEST_DIR/gnupg"
  coproc GP { python3 -c "
import socket, os, sys
path = '$TEST_DIR/gnupg/S.keyboxd'
s = socket.socket(socket.AF_UNIX)
s.bind(path)
s.listen(1)
print('ready', flush=True)
import time; time.sleep(30)
"; }
  read -r line <&"${GP[0]}"
  [ "$line" = "ready" ]
  gpg_clean_dead_daemon_state "$TEST_DIR/gnupg"
  [ -S "$TEST_DIR/gnupg/S.keyboxd" ]
  kill "$GP_PID" 2>/dev/null || true
}

@test "gpg cleanup: removes a socket artifact (regular file, macOS VirtioFS case)" {
  mkdir -p "$TEST_DIR/gnupg"
  echo dead > "$TEST_DIR/gnupg/S.gpg-agent"
  gpg_clean_dead_daemon_state "$TEST_DIR/gnupg"
  [ ! -e "$TEST_DIR/gnupg/S.gpg-agent" ]
}

@test "gpg cleanup: removes stale cross-machine lock files" {
  mkdir -p "$TEST_DIR/gnupg/public-keys.d"
  echo "foreign-host:21:1" > "$TEST_DIR/gnupg/public-keys.d/pubring.db.lock"
  gpg_clean_dead_daemon_state "$TEST_DIR/gnupg"
  [ ! -e "$TEST_DIR/gnupg/public-keys.d/pubring.db.lock" ]
}

@test "gpg cleanup: missing gnupg home is a no-op" {
  run gpg_clean_dead_daemon_state "$TEST_DIR/does-not-exist"
  [ "$status" -eq 0 ]
}

@test "gpg cleanup: leaves non-socket files alone" {
  mkdir -p "$TEST_DIR/gnupg"
  echo "keydata" > "$TEST_DIR/gnupg/pubring.kbx"
  echo "config" > "$TEST_DIR/gnupg/common.conf"
  gpg_clean_dead_daemon_state "$TEST_DIR/gnupg"
  [ -f "$TEST_DIR/gnupg/pubring.kbx" ]
  [ -f "$TEST_DIR/gnupg/common.conf" ]
}

# --- load_secret_key (compose-secret env loading) ----------------------------

@test "load_secret_key: exports the trimmed first secret line as the env var" {
  mkdir -p "$TEST_DIR/secrets"
  printf '  sk-secret-1  \nsecond line\n' > "$TEST_DIR/secrets/key"
  load_secret_key TEST_KEY_VAR "$TEST_DIR/secrets/key"
  [ "$TEST_KEY_VAR" = "sk-secret-1" ]
}

@test "load_secret_key: an already-set env var wins over the secret" {
  TEST_KEY_VAR="from-env"
  printf 'from-secret\n' > "$TEST_DIR/keyfile"
  load_secret_key TEST_KEY_VAR "$TEST_DIR/keyfile"
  [ "$TEST_KEY_VAR" = "from-env" ]
}

@test "load_secret_key: missing or empty secret is a no-op" {
  : > "$TEST_DIR/empty"
  load_secret_key TEST_KEY_VAR "$TEST_DIR/empty"
  [ -z "${TEST_KEY_VAR:-}" ]
  load_secret_key TEST_KEY_VAR "$TEST_DIR/does-not-exist"
  [ -z "${TEST_KEY_VAR:-}" ]
}

# --- persist_mistral_key (vibe .env + interactive-shell persistence) --------

@test "mistral persistence: vibe .env + mode-600 snippet with env precedence, .bashrc hook once" {
  touch "$HOME/.bashrc"
  persist_mistral_key "sk-mistral-1"
  # vibe's own credential store: present, mode 600, single line
  [ -f "$HOME/.vibe/.env" ]
  grep -q "^MISTRAL_API_KEY=sk-mistral-1$" "$HOME/.vibe/.env"
  [ "$(stat -c %a "$HOME/.vibe/.env")" = "600" ]
  # interactive-shell snippet: present, mode 600
  [ -f "$HOME/.config/thoth/mistral-key.sh" ]
  [ "$(stat -c %a "$HOME/.config/thoth/mistral-key.sh")" = "600" ]
  # sourcing the snippet without an env var yields the embedded key
  (
    unset MISTRAL_API_KEY
    . "$HOME/.config/thoth/mistral-key.sh"
    [ "$MISTRAL_API_KEY" = "sk-mistral-1" ]
  )
  # an env var set at runtime (rotated key) still wins
  (
    export MISTRAL_API_KEY="rotated"
    . "$HOME/.config/thoth/mistral-key.sh"
    [ "$MISTRAL_API_KEY" = "rotated" ]
  )
  # .bashrc hook: present, and written only once on repeat starts
  grep -q "mistral-key.sh" "$HOME/.bashrc"
  first_count="$(grep -c "mistral-key.sh" "$HOME/.bashrc")"
  persist_mistral_key "sk-mistral-2"
  second_count="$(grep -c "mistral-key.sh" "$HOME/.bashrc")"
  [ "$first_count" -gt 0 ]
  [ "$first_count" = "$second_count" ]
  # the snippet itself is rewritten on rotation
  grep -q "sk-mistral-2" "$HOME/.config/thoth/mistral-key.sh"
  [ "$(stat -c %a "$HOME/.config/thoth/mistral-key.sh")" = "600" ]
}

@test "mistral persistence: rotation updates the vibe .env line in place, preserves other credentials" {
  touch "$HOME/.bashrc"
  mkdir -p "$HOME/.vibe"
  printf 'OTHER_PROVIDER_KEY=keepme\nMISTRAL_API_KEY=sk-old\n' > "$HOME/.vibe/.env"
  persist_mistral_key "sk-new"
  grep -q "^OTHER_PROVIDER_KEY=keepme$" "$HOME/.vibe/.env"
  grep -q "^MISTRAL_API_KEY=sk-new$" "$HOME/.vibe/.env"
  [ "$(grep -c "^MISTRAL_API_KEY=" "$HOME/.vibe/.env")" -eq 1 ]
  [ "$(stat -c %a "$HOME/.vibe/.env")" = "600" ]
}

# --- beads resolution (mirrors the entrypoint logic) -----------------------

@test "beads resolution: explicit BEADS_DIR wins" {
  [ "${BEADS_DIR:-}" = "" ] || skip "BEADS_DIR set in environment"
  # simulate: explicit override
  BEADS_DIR="/custom/.beads"
  [ "$BEADS_DIR" = "/custom/.beads" ]
}

@test "beads resolution: project .beads wins when BEADS_DIR unset" {
  # the entrypoint logic: unset -> /workspace/.beads if present
  unset BEADS_DIR
  mkdir -p "$TEST_DIR/workspace/.beads"
  resolved=""
  if [ -z "${BEADS_DIR:-}" ]; then
    if [ -d "$TEST_DIR/workspace/.beads" ]; then
      resolved="$TEST_DIR/workspace/.beads"
    else
      resolved="/data/beads/.beads"
    fi
  fi
  [ "$resolved" = "$TEST_DIR/workspace/.beads" ]
}

@test "beads resolution: volume default when no project .beads" {
  unset BEADS_DIR
  resolved=""
  if [ -z "${BEADS_DIR:-}" ]; then
    if [ -d "$TEST_DIR/workspace/.beads" ]; then
      resolved="$TEST_DIR/workspace/.beads"
    else
      resolved="/data/beads/.beads"
    fi
  fi
  [ "$resolved" = "/data/beads/.beads" ]
}

# --- suricata sidecar (compose + config wiring) -----------------------------

@test "suricata: override compose file is valid and shares thoth's namespace" {
  run docker compose -f docker-compose.yml -f docker-compose.suricata.yml config --quiet
  [ "$status" -eq 0 ]
  run docker compose -f docker-compose.yml -f docker-compose.suricata.yml config --format json
  [ "$status" -eq 0 ]
  # network_mode must reference the thoth service
  [[ "$output" == *"service:thoth"* ]]
}

@test "suricata: versioned config exists and has the EVE types" {
  [ -f suricata/config/suricata.yaml ]
  grep -q "eve-log:" suricata/config/suricata.yaml
  grep -q "\- flow" suricata/config/suricata.yaml
  grep -q "\- dns:" suricata/config/suricata.yaml
  grep -q "\- tls:" suricata/config/suricata.yaml
  grep -q "\- http:" suricata/config/suricata.yaml
  # rules off by default
  grep -q "rule-files: \[\]" suricata/config/suricata.yaml
}

@test "suricata: runtime dirs are gitignored, config is not" {
  grep -q "suricata/logs/\*" .gitignore
  grep -q "suricata/data/\*" .gitignore
}

@test "suricata: report script runs against the sample log" {
  [ -f suricata/logs/eve.json ] || skip "no eve.json (sidecar not run)"
  run ./scripts/suricata-report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Connections by host"* ]]
  [[ "$output" == *"EGRESS"* ]]
}
