#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expect_store="${MTAXI_POSTDEPLOY_EXPECT_STORE:-postgres}"
. "$root_dir/scripts/remote_backend_url_guard.sh"

fail() {
  echo "MTaxi VPS postdeploy check failed: $*" >&2
  exit 1
}

env_public_base_url=""
if [ -f "$root_dir/server/.env" ]; then
  env_public_base_url="$(
    awk -F= '
      $1 == "MTAXI_PUBLIC_BASE_URL" {
        value = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^'\''|'\''$/, "", value)
        gsub(/^"|"$/, "", value)
        print value
        exit
      }
    ' "$root_dir/server/.env"
  )"
fi

base_url="${MTAXI_POSTDEPLOY_BASE_URL:-${1:-${env_public_base_url:-http://127.0.0.1:8080}}}"

case "$base_url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) base_url="$(mtaxi_validate_remote_backend_url "$base_url" "MTaxi VPS postdeploy check failed")" ;;
esac

echo "MTaxi VPS postdeploy: ops check"
MTAXI_OPS_BASE_URL="$base_url" \
MTAXI_OPS_EXPECT_STORE="$expect_store" \
  "$root_dir/deploy/ops_check.sh"

echo "MTaxi VPS postdeploy: backend smoke"
(
  cd "$root_dir/server"
  MTAXI_SMOKE_BASE_URL="$base_url" \
  MTAXI_SMOKE_EXPECT_STORE="$expect_store" \
    npm run smoke
)

echo "MTaxi VPS postdeploy check passed: $base_url"
