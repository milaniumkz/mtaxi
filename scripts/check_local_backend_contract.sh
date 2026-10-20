#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_url="${MTAXI_LOCAL_BACKEND_URL:-${1:-http://127.0.0.1:8080}}"
expected_store="${MTAXI_LOCAL_EXPECT_STORE:-${2:-}}"

fail() {
  echo "MTaxi local backend contract check failed: $*" >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail "node is required"

case "$expected_store" in
  ""|json|postgres) ;;
  *) fail "expected store must be json or postgres" ;;
esac

(
  cd "$root_dir/server"
  MTAXI_SMOKE_BASE_URL="$base_url" \
    MTAXI_SMOKE_EXPECT_STORE="$expected_store" \
    npm run smoke
)

echo "MTaxi local backend contract check passed: $base_url"
