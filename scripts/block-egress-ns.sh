#!/bin/sh
# block-egress-ns.sh - runs INSIDE thoth's network namespace (via
# scripts/block-egress.sh). Requires: iptables, ip6tables, getent.
# The blocklist is mounted at /blocklist.

set -eu

MARK="-m comment --comment thoth-block"

is_domain() {
  case "$1" in
    *[!a-zA-Z0-9.-]*) return 1 ;;  # anything but hostname chars -> not a domain
    *[a-zA-Z-]*.*) return 0 ;;     # contains letters + dot -> domain
    *) return 1 ;;                # digits and dots only -> IP
  esac
}

resolve() {
  # all A + AAAA records, IPv4 and IPv6
  getent ahosts "$1" | awk '{print $1}' | sort -u || true
}

add_target() {
  target="$1"
  if is_domain "$target"; then
    echo "resolving $target ..."
    for ip in $(resolve "$target"); do
      add_ip "$ip"
    done
  else
    add_ip "$target"
  fi
}

add_ip() {
  ip="$1"
  case "$ip" in
    *:*) ip6tables -C OUTPUT -d "$ip" -j DROP $MARK 2>/dev/null || ip6tables -A OUTPUT -d "$ip" -j DROP $MARK ;;
    *)   iptables  -C OUTPUT -d "$ip" -j DROP $MARK 2>/dev/null || iptables  -A OUTPUT -d "$ip" -j DROP $MARK ;;
  esac
  echo "  blocked $ip"
}

remove_ip() {
  ip="$1"
  case "$ip" in
    *:*) ip6tables -D OUTPUT -d "$ip" -j DROP $MARK 2>/dev/null || true ;;
    *)   iptables  -D OUTPUT -d "$ip" -j DROP $MARK 2>/dev/null || true ;;
  esac
}

case "${1:-}" in
  add)
    echo "$2" >> /dev/null 2>&1 || true   # target passed as arg
    add_target "$2"
    ;;
  remove)
    target="$2"
    if is_domain "$target"; then
      for ip in $(resolve "$target"); do remove_ip "$ip"; done
    else
      remove_ip "$target"
    fi
    echo "removed $target (where present)"
    ;;
  list)
    echo "── IPv4 OUTPUT blocks ──"
    iptables -L OUTPUT -n 2>/dev/null | grep -E "DROP.*thoth-block" || echo "  (none)"
    echo "── IPv6 OUTPUT blocks ──"
    ip6tables -L OUTPUT -n 2>/dev/null | grep -E "DROP.*thoth-block" || echo "  (none)"
    ;;
  clear)
    while iptables  -L OUTPUT -n 2>/dev/null | grep -q thoth-block; do
      iptables  -D OUTPUT -d "$(iptables -L OUTPUT -n | awk '/thoth-block/{print $4; exit}') -j DROP $MARK" 2>/dev/null || break
    done
    # simpler: flush by comment via iptables-save/restore
    iptables-save 2>/dev/null | grep -v thoth-block | iptables-restore 2>/dev/null || true
    ip6tables-save 2>/dev/null | grep -v thoth-block | ip6tables-restore 2>/dev/null || true
    echo "cleared all thoth-block rules"
    ;;
  refresh)
    # re-apply everything in the blocklist (removes stale, adds new IPs)
    iptables-save  2>/dev/null | grep -v thoth-block | iptables-restore  2>/dev/null || true
    ip6tables-save 2>/dev/null | grep -v thoth-block | ip6tables-restore 2>/dev/null || true
    if [ -f /blocklist ]; then
      grep -vE '^\s*(#|$)' /blocklist | while read -r target; do
        [ -n "$target" ] && add_target "$target"
      done
    fi
    echo "refreshed from /blocklist"
    ;;
  *) echo "usage: ns.sh {add|remove|list|clear|refresh} [target]" >&2; exit 1 ;;
esac
