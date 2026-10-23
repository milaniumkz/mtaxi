#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${1:?Pass the public Firebase web config JSON file}"
backend_url="${2:?Pass the HTTPS backend URL}"
. "$root_dir/scripts/remote_backend_url_guard.sh"
backend_url="$(mtaxi_validate_remote_backend_url "$backend_url" "Firebase web build failed")"
defines_file="$(mktemp)"
trap 'rm -f "$defines_file"' EXIT
node "$root_dir/scripts/configure_firebase_web.js" "$config_file" "$backend_url" "$defines_file" "$root_dir/web/firebase-config.js"
cd "$root_dir"
"${FLUTTER_BIN:-flutter}" build web --no-web-resources-cdn --dart-define-from-file="$defines_file" --dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true
test -f build/web/firebase-messaging-sw.js
test -f build/web/firebase-config.js
MTAXI_BACKEND_URL="$backend_url" bash scripts/check_web_backend_artifact.sh build/web
