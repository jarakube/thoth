#!/usr/bin/env bash
# suricata-report.sh - easy overview of what the thoth container has
# been talking to, from the Suricata sidecar's EVE JSON log.
#
# Usage:
#   ./scripts/suricata-report.sh              # full report
#   ./scripts/suricata-report.sh --live      # watch mode (refresh 10s)
#   EVE=other-eve.json ./scripts/suricata-report.sh
#
# Requires: jq. Sections:
#   - sensor health (capture drops)
#   - connections by host: egress/ingress bytes, flow counts
#     (host = TLS SNI when observed, else the destination IP)
#   - totals and recent-connections timeline

set -euo pipefail
cd "$(dirname "$0")/.."

EVE="${EVE:-suricata/logs/eve.json}"
[ -f "$EVE" ] || { echo "No EVE log at $EVE - is the sidecar running? (make suricata-up)" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

generate() {
  jq -rs '
    # ---- SNI map: dest_ip -> hostname (from TLS events) ----------------
    ( [ .[] | select(.event_type == "tls") ]
      | reduce .[] as $t ({}; .[$t.dest_ip] = (.[$t.dest_ip] // ($t.tls.sni // empty)))
    ) as $sni
    |
    # ---- container IPs: src of egress TCP flows -------------------------
    ( [ .[] | select(.event_type == "flow" and .proto == "TCP")
        | select(.src_ip | test("^172\\.|^10\\.|^192\\.168\\.")) ]
      | map(.src_ip) | unique ) as $cips
    |
    ( [ .[] | select(.event_type == "flow" and .proto == "TCP")
        | select(.src_ip as $s | $cips | index($s)) ] ) as $egress
    |
    # ---- human-readable byte helper --------------------------------------
    def kb: if . >= 1048576 then "\((. / 1048576) * 10 | round / 10) MB"
            elif . >= 1024    then "\((. / 1024) | round) KB"
            else "\(.) B" end;
    def pad($n): tostring | if length < $n then . + (" " * ($n - length)) else . end;

    "════════════════════════════════════════════════════════════════",
    " Suricata report - \($EVE_FILE) (\(length) events)",
    "════════════════════════════════════════════════════════════════",
    "",
    "── Sensor health (last stats event) ──",
    ( [ .[] | select(.event_type == "stats") ] | last
      | if . == null then "  (no stats events)"
        else "  packets: \(.stats.capture.kernel_packets)  drops: \(.stats.capture.kernel_drops)  errors: \(.stats.capture.errors)  (at \(.timestamp[0:19]))" end ),
    "",
    "── Connections by host ──",
    "  (host = TLS SNI when observed, else dest IP; egress = container→net, ingress = net→container)",
    "",
    "  \( "HOST" | pad(38) )  \( "FLOWS" | pad(5) )  \( "EGRESS" | pad(10) )  \( "INGRESS" | pad(10) )  PROTO",
    ( $egress
      | group_by(. as $f | ($sni[$f.dest_ip] // $f.dest_ip))
      | map({
          host: (.[0] as $f | ($sni[$f.dest_ip] // $f.dest_ip)),
          flows: length,
          up: (map(.flow.bytes_toserver) | add),
          down: (map(.flow.bytes_toclient) | add),
          proto: (map(.app_proto // "tcp") | unique | join(","))
        })
      | sort_by(-(.up + .down))
      | .[]
      | "  \( (.host | tostring | .[0:38]) | pad(38) )  \( (.flows | tostring | pad(5)) )  \( (.up | kb | pad(10)) )  \( (.down | kb | pad(10)) )  \(.proto)" ),
    "",
    "── Totals (container egress TCP flows) ──",
    "  flows: \($egress | length)   egress: \( ($egress | map(.flow.bytes_toserver) | add // 0) | kb )   ingress: \( ($egress | map(.flow.bytes_toclient) | add // 0) | kb )",
    "",
    "── Recent connections (last 15 TCP flows) ──",
    ( [ .[] | select(.event_type == "flow" and .proto == "TCP") ] | .[-15:]
      | .[]
      | "  \(.timestamp[0:19])  \(.src_ip):\(.src_port) → \(.dest_ip):\(.dest_port)  \(.app_proto // "tcp")" )
  ' --arg EVE_FILE "$EVE" "$EVE"
}

if [ "${1:-}" = "--live" ]; then
  while true; do
    clear
    generate
    echo
    echo "(refreshing every 10s - Ctrl-C to quit)"
    sleep 10
  done
else
  generate
fi
