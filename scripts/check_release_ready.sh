#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_url="${MTAXI_BACKEND_URL:-${1:-}}"
flutter_bin="${FLUTTER_BIN:-flutter}"
. "$root_dir/scripts/remote_backend_url_guard.sh"

fail() {
  echo "MTaxi release readiness failed: $*" >&2
  exit 1
}

api_url="$(mtaxi_validate_remote_backend_url "$api_url" "MTaxi release readiness failed")"

"$root_dir/scripts/check_firebase_fcm_only.sh"
"$root_dir/scripts/check_client_backend_only_static.sh"

command -v "$flutter_bin" >/dev/null 2>&1 ||
  fail "Flutter SDK not found. Set FLUTTER_BIN or install Flutter before release readiness check"

"$root_dir/scripts/check_firebase_fcm_only.sh"

(
  cd "$root_dir/server"
  MTAXI_SMOKE_BASE_URL="$api_url" MTAXI_SMOKE_EXPECT_STORE=postgres npm run smoke
)

(
  cd "$root_dir"
  "$flutter_bin" test test/backend_only_guard_test.dart
)

echo "MTaxi release readiness passed: $api_url"
echo "Next:"
echo "  MTAXI_BACKEND_URL=$api_url ./scripts/build_backend_release.sh web|apk|ios"
