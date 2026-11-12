#!/usr/bin/env bash
# block-egress.sh - manage egress blocks for the thoth container.
#
# Applies iptables/ip6tables rules in thoth's network namespace, so the
# agents cannot connect to the given IPs or domains. A domain is
# resolved at apply time and ALL its addresses (IPv4 + IPv6) are
# blocked; re-run after DNS changes (see --refresh).
#
# The rules live in the network namespace: they persist as long as the
# thoth container exists and are removed with --clear (or when the
# container is recreated).
#
# Usage:
#   ./scripts/block-egress.sh add 1.2.3.4            # block an IP
#   ./scripts/block-egress.sh add bad.example.com    # block a domain (all its IPs)
#   ./scripts/block-egress.sh list                   # show active blocks
#   ./scripts/block-egress.sh remove 1.2.3.4         # remove one block
#   ./scripts/block-egress.sh clear                  # remove all blocks
#   ./scripts/block-egress.sh refresh               # re-resolve domains in the blocklist
#
# Blocklist file: suricata/blocklist (one IP or domain per line, # comments).
# Applied by make block-egress (see below); kept in sync with --refresh.
#
# Requirements: the thoth container must be running; the blocking
# container runs with NET_ADMIN in thoth's network namespace.

set -euo pipefail
cd "$(dirname "$0")/.."

BLOCKLIST="${BLOCKLIST:-suricata/blocklist}"
HELPER_IMAGE="alpine:3.20"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# Run a command inside thoth's network namespace with NET_ADMIN.
ns_exec() {
  local app_id
  app_id="$(docker compose ps -q thoth)"
  [ -n "$app_id" ] || { echo "ERROR: thoth container not running" >&2; exit 1; }
  docker run --rm --network "container:${app_id}" --cap-add NET_ADMIN \
    -v "$(pwd)/scripts/block-egress-ns.sh:/ns.sh:ro" \
    -v "$(pwd)/${BLOCKLIST}:/blocklist:ro" \
    --entrypoint sh "${HELPER_IMAGE}" \
    -c 'apk add -q iptables ip6tables >/dev/null 2>&1; sh /ns.sh "$@"' sh "$@"
}

case "${1:-}" in
  add)    [ $# -ge 2 ] || usage; ns_exec add "$2" ;;
  remove) [ $# -ge 2 ] || usage; ns_exec remove "$2" ;;
  list)   ns_exec list ;;
  clear)  ns_exec clear ;;
  refresh) ns_exec refresh ;;
  *)      usage ;;
esac
