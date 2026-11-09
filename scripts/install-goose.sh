#!/usr/bin/env bash

set -euo pipefail

version="${GOOSE_VERSION:-v1.25.0}"
bin_dir="${GOOSE_BIN_DIR:-/usr/local/bin}"
linux_variant="${GOOSE_LINUX_VARIANT:-}"

case "$(uname -m)" in
  x86_64) arch="x86_64" ;;
  aarch64|arm64) arch="aarch64" ;;
  *)
    printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

detect_linux_variant() {
  if [ -n "$linux_variant" ]; then
    printf '%s\n' "$linux_variant"
    return
  fi

  if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
    printf 'musl\n'
    return
  fi

  printf 'standard\n'
}

linux_variant="$(detect_linux_variant)"

case "$linux_variant" in
  standard) archive="goose-${arch}-unknown-linux-gnu.tar.bz2" ;;
  vulkan) archive="goose-${arch}-unknown-linux-gnu-vulkan.tar.bz2" ;;
  musl) archive="goose-${arch}-unknown-linux-musl.tar.bz2" ;;
  *)
    printf 'Unsupported linux variant: %s\n' "$linux_variant" >&2
    exit 1
    ;;
esac

url="https://github.com/aaif-goose/goose/releases/download/${version}/${archive}"
tmpdir="$(mktemp -d)"
archive_path="${tmpdir}/${archive}"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$bin_dir"

curl \
  --fail \
  --show-error \
  --location \
  --retry 5 \
  --retry-delay 2 \
  --retry-all-errors \
  --connect-timeout 20 \
  --max-time 900 \
  "$url" \
  --output "$archive_path"

tar -xjf "$archive_path" -C "$tmpdir"
install -m 0755 "$tmpdir/goose" "$bin_dir/goose"
