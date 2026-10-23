#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${MTAXI_BACKEND_HOST:?Render backend hostname is required}"
backend_url="https://${MTAXI_BACKEND_HOST}"
. "$root_dir/scripts/remote_backend_url_guard.sh"
backend_url="$(mtaxi_validate_remote_backend_url "$backend_url" 'Render web build failed')"
flutter_dir="${MTAXI_RENDER_FLUTTER_DIR:-/tmp/mtaxi-render-flutter}"
if [ ! -d "$flutter_dir/.git" ]; then
  git clone --depth 1 --branch 3.41.2 https://github.com/flutter/flutter.git "$flutter_dir"
fi
test "$(git -C "$flutter_dir" rev-parse HEAD)" = 90673a4eef275d1a6692c26ac80d6d746d41a73a
export PATH="$flutter_dir/bin:$PATH"
export CI=true
cd "$root_dir"
flutter pub get --enforce-lockfile
flutter build web --no-web-resources-cdn --dart-define="MTAXI_BACKEND_URL=$backend_url" --dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true
MTAXI_BACKEND_URL="$backend_url" bash scripts/check_web_backend_artifact.sh build/web
