#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
web_dir="${1:-$root_dir/build/web}"
expected_url="${MTAXI_BACKEND_URL:-${2:-}}"

fail() {
  echo "MTaxi web artifact check failed: $*" >&2
  exit 1
}

[ -d "$web_dir" ] || fail "web build directory not found: $web_dir"
[ -f "$web_dir/main.dart.js" ] || fail "main.dart.js not found in $web_dir"

if [ -n "$expected_url" ]; then
  grep -F "$expected_url" "$web_dir/main.dart.js" >/dev/null ||
    fail "expected MTAXI_BACKEND_URL is missing from web artifact"
fi

local_backend_url_pattern='https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.0\.2\.2|10\.[0-9.]+|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9.]+|169\.254\.[0-9.]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9.]+|192\.168\.[0-9.]+|\[?::1\]?|\[?f[cd][0-9a-f:]*\]?|\[?fe(8|9|a|b)[0-9a-f:]*\]?)(:|/|")'
if grep -E "$local_backend_url_pattern" "$web_dir/main.dart.js" >/dev/null; then
  fail "web artifact contains local backend URL"
fi

if grep -E 'MTAXI_REQUIRE_REMOTE_BACKEND[^=]*false|requireRemoteBackend[^=]*false' "$web_dir/main.dart.js" >/dev/null; then
  fail "web artifact appears to disable remote backend requirement"
fi

echo "MTaxi web artifact backend check passed: $web_dir"
