#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
api_url="${MTAXI_BACKEND_URL:-${2:-}}"
flutter_bin="${FLUTTER_BIN:-flutter}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$root_dir/scripts/remote_backend_url_guard.sh"

fail() {
  echo "MTaxi release build failed: $*" >&2
  exit 1
}

case "$target" in
  web|apk|ios) ;;
  *) fail "usage: MTAXI_BACKEND_URL=https://api.mtaxi.kz $0 web|apk|ios" ;;
esac

api_url="$(mtaxi_validate_remote_backend_url "$api_url" "MTaxi release build failed")"

defines=(
  "--dart-define=MTAXI_BACKEND_URL=$api_url"
  "--dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true"
)

MTAXI_BACKEND_URL="$api_url" FLUTTER_BIN="$flutter_bin" "$root_dir/scripts/check_release_ready.sh"

case "$target" in
  web)
    "$flutter_bin" build web --release "${defines[@]}"
    MTAXI_BACKEND_URL="$api_url" "$root_dir/scripts/check_web_backend_artifact.sh" "$root_dir/build/web"
    ;;
  apk)
    "$flutter_bin" build apk --release "${defines[@]}"
    MTAXI_BACKEND_URL="$api_url" "$root_dir/scripts/check_mobile_backend_artifact.sh" apk
    ;;
  ios)
    "$flutter_bin" build ipa --release "${defines[@]}"
    MTAXI_BACKEND_URL="$api_url" "$root_dir/scripts/check_mobile_backend_artifact.sh" ios
    ;;
esac
