#!/usr/bin/env bash
# Integration test for scripts/block-egress.sh - egress blocking of an
# IP address in a shared network namespace (the mechanism block-egress.sh
# applies to thoth). Deterministic: dedicated docker network + helper
# http server with a fixed IP; no external hosts involved.

bats_require_minimum_version 1.5.0

ROOT="$BATS_TEST_DIRNAME/.."
TEST_NET="thoth-blocktest-net"
TEST_IP="10.99.99.99"
HELPER="thoth-blocktest-helper"
# alpine + curl + iptables, ready to run in the namespace under test
CLIENT="alpine:3.20"
CLIENT_PREP="apk add -q curl iptables >/dev/null 2>&1;"

setup_file() {
  docker network create thoth-blocktest-net --subnet 10.99.99.0/24 >/dev/null 2>&1 || true
  docker run -d --name thoth-blocktest-helper \
    --network thoth-blocktest-net --ip 10.99.99.99 \
    python:3-alpine python3 -m http.server 80 --bind 0.0.0.0 >/dev/null
  sleep 2
}

teardown_file() {
  docker rm -f thoth-blocktest-helper >/dev/null 2>&1 || true
  docker network rm thoth-blocktest-net >/dev/null 2>&1 || true
}

@test "block-egress: scripts exist and are executable" {
  [ -x "$ROOT/scripts/block-egress.sh" ]
  [ -x "$ROOT/scripts/block-egress-ns.sh" ]
}

@test "block-egress: target is reachable before blocking" {
  run docker run --rm --network thoth-blocktest-net \
    $CLIENT sh -c "$CLIENT_PREP curl -s -o /dev/null -w '%{http_code}' -m 5 http://10.99.99.99/"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

@test "block-egress: blocking an IP address cuts connectivity" {
  # add the block AND probe connectivity in ONE namespace: rules created
  # via NET_ADMIN in a namespace apply to traffic from that same namespace
  run docker run --rm --network thoth-blocktest-net --cap-add NET_ADMIN \
    -v "$ROOT/scripts/block-egress-ns.sh:/ns.sh:ro" \
    $CLIENT sh -c "
      $CLIENT_PREP
      sh /ns.sh add $TEST_IP
      curl -s -o /dev/null -w '%{http_code}' -m 5 http://$TEST_IP/ || true
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocked $TEST_IP"* ]]
  [[ "$output" == *"000"* ]]
}

@test "block-egress: blocklist file applies via refresh and blocks" {
  printf '# test blocklist\n%s\n' "$TEST_IP" > "$BATS_TEST_TMPDIR/blocklist"
  run docker run --rm --network thoth-blocktest-net --cap-add NET_ADMIN \
    -v "$ROOT/scripts/block-egress-ns.sh:/ns.sh:ro" \
    -v "$BATS_TEST_TMPDIR/blocklist:/blocklist:ro" \
    $CLIENT sh -c "
      $CLIENT_PREP
      sh /ns.sh refresh
      curl -s -o /dev/null -w '%{http_code}' -m 5 http://$TEST_IP/ || true
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocked $TEST_IP"* ]]
  [[ "$output" == *"000"* ]]
}

@test "block-egress: ns script list shows the marked rules" {
  run docker run --rm --network thoth-blocktest-net --cap-add NET_ADMIN \
    -v "$ROOT/scripts/block-egress-ns.sh:/ns.sh:ro" \
    $CLIENT sh -c "
      $CLIENT_PREP
      sh /ns.sh add $TEST_IP >/dev/null
      sh /ns.sh list
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_IP"* ]]
  [[ "$output" == *"thoth-block"* ]]
}

@test "block-egress: clear removes all thoth-block rules" {
  run docker run --rm --network thoth-blocktest-net --cap-add NET_ADMIN \
    -v "$ROOT/scripts/block-egress-ns.sh:/ns.sh:ro" \
    $CLIENT sh -c "
      $CLIENT_PREP
      sh /ns.sh add $TEST_IP >/dev/null
      sh /ns.sh clear
      sh /ns.sh list
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"(none)"* ]]
}

@test "block-egress: blocking a DOMAIN resolves and blocks all its IPs" {
  # domain blocking: resolve + block all A/AAAA records. We assert on
  # the resolved-and-blocked rules (at least one), not on external
  # reachability, so the test is independent of the domain's uptime.
  run docker run --rm --cap-add NET_ADMIN \
    -v "$ROOT/scripts/block-egress-ns.sh:/ns.sh:ro" \
    $CLIENT sh -c "
      $CLIENT_PREP
      sh /ns.sh add one.one.one.one
      sh /ns.sh list
    "
  [ "$status" -eq 0 ]
  [[ "$output" == *"resolving one.one.one.one"* ]]
  # at least one concrete IP blocked (v4 or v6)
  echo "$output" | grep -qE "blocked (1\.|2606:)"
  [[ "$output" == *"thoth-block"* ]]
}
