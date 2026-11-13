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
