#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-}"
artifact="${2:-}"
expected_url="${MTAXI_BACKEND_URL:-${3:-}}"

fail() {
  echo "MTaxi mobile artifact check failed: $*" >&2
  exit 1
}

case "$target" in
  apk)
    artifact="${artifact:-$root_dir/build/app/outputs/flutter-apk/app-release.apk}"
    ;;
  ios|ipa)
    if [ -z "$artifact" ]; then
      artifact="$(find "$root_dir/build/ios/ipa" -maxdepth 1 -name '*.ipa' -print 2>/dev/null | head -1 || true)"
    fi
    ;;
  *)
    fail "usage: $0 apk|ios [artifact]"
    ;;
esac

[ -f "$artifact" ] || fail "artifact not found: $artifact"
command -v unzip >/dev/null 2>&1 || fail "unzip not found"
command -v strings >/dev/null 2>&1 || fail "strings not found"

tmp_text="$(mktemp)"
trap 'rm -f "$tmp_text"' EXIT

while IFS= read -r entry; do
  case "$entry" in
    *.so|*.dylib|*/App|*/Runner|*/Runner.app/Runner)
      unzip -p "$artifact" "$entry" 2>/dev/null | strings -a >>"$tmp_text" || true
      ;;
  esac
done < <(unzip -Z1 "$artifact")

[ -s "$tmp_text" ] || fail "no inspectable binary payload found in artifact"

if [ -n "$expected_url" ]; then
  grep -F "$expected_url" "$tmp_text" >/dev/null ||
    fail "expected MTAXI_BACKEND_URL is missing from mobile artifact"
fi

local_backend_url_pattern='https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.0\.2\.2|10\.[0-9.]+|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9.]+|169\.254\.[0-9.]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9.]+|192\.168\.[0-9.]+|\[?::1\]?|\[?f[cd][0-9a-f:]*\]?|\[?fe(8|9|a|b)[0-9a-f:]*\]?)(:|/|$)'
if grep -E "$local_backend_url_pattern" "$tmp_text" >/dev/null; then
  fail "mobile artifact contains local backend URL"
fi

echo "MTaxi mobile artifact backend check passed: $artifact"
