#!/usr/bin/env bash
# init-suricata.sh - one-time Suricata sidecar initialization.
#
# The reviewed sensor configuration (suricata/config/suricata.yaml) is
# version-controlled in this repository - nothing to generate. This
# script only prepares the runtime directories and validates the config
# against the Suricata image.
#
# Usage: ./scripts/init-suricata.sh   (or: make suricata-init)

set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="jasonish/suricata:8.0"

mkdir -p suricata/config suricata/data suricata/logs

test -f suricata/config/suricata.yaml || {
  echo "ERROR: suricata/config/suricata.yaml missing (version-controlled file)" >&2
  exit 1
}

echo "Validating suricata/config/suricata.yaml with ${IMAGE}..."
docker run --rm \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_NICE \
  -v "$(pwd)/suricata/config/suricata.yaml:/etc/suricata/suricata.yaml:ro" \
  --entrypoint sh \
  "${IMAGE}" -c 'suricata -T -c /etc/suricata/suricata.yaml 2>&1 | tail -2'

echo
echo "Config valid. Next steps:"
echo "  make suricata-up     # start thoth + suricata sidecar"
echo "  tail -f suricata/logs/eve.json   # watch events"
