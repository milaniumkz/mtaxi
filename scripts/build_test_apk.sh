#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_url="${1:?Pass the actual deployed HTTPS backend URL}"
. "$root_dir/scripts/remote_backend_url_guard.sh"
backend_url="$(mtaxi_validate_remote_backend_url "$backend_url" 'Test APK build failed')"
health_file="$(mktemp)"
trap 'rm -f "$health_file"' EXIT
curl --fail --silent --show-error --max-time 120 "${backend_url%/}/readyz" -o "$health_file"
node - "$health_file" <<'NODE'
const fs = require('fs');
const health = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (health.ok !== true || health.service !== 'mtaxi-backend' || health.store?.type !== 'postgres') {
  throw new Error('The remote MTaxi PostgreSQL backend is not ready');
}
NODE
cd "$root_dir"
flutter build apk --profile --dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true --dart-define="MTAXI_BACKEND_URL=$backend_url"
mkdir -p output
cp build/app/outputs/flutter-apk/app-profile.apk output/mtaxi-staging.apk
(cd output && sha256sum mtaxi-staging.apk > mtaxi-staging.apk.sha256)
printf 'Test APK built: %s/output/mtaxi-staging.apk\n' "$root_dir"
