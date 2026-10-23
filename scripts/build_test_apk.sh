#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_url="${1:?Pass the actual deployed HTTPS backend URL}"
. "$root_dir/scripts/remote_backend_url_guard.sh"
backend_url="$(mtaxi_validate_remote_backend_url "$backend_url" 'Test APK build failed')"
export MTAXI_TEST_KEYSTORE="${MTAXI_TEST_KEYSTORE:-$HOME/.android/debug.keystore}"
if [[ ! -f "$MTAXI_TEST_KEYSTORE" ]]; then
  printf 'Restore the persistent test signing key before building: %s\n' "$MTAXI_TEST_KEYSTORE" >&2
  exit 1
fi
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
apksigner_bin="$(find "${sdk_root:?Android SDK is required}/build-tools" -name apksigner | sort -V | tail -1)"
[[ -x "$apksigner_bin" ]] || { printf 'apksigner is required\n' >&2; exit 1; }
health_file="$(mktemp)"
certificate_file="$(mktemp)"
trap 'rm -f "$health_file" "$certificate_file"' EXIT
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
keytool -exportcert -keystore "$MTAXI_TEST_KEYSTORE" -storepass android -alias androiddebugkey -file "$certificate_file" >/dev/null
expected_certificate="$(sha256sum "$certificate_file" | cut -d ' ' -f 1)"
actual_certificate="$("$apksigner_bin" verify --print-certs build/app/outputs/flutter-apk/app-profile.apk | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')"
if [[ "$actual_certificate" != "$expected_certificate" ]]; then
  printf 'APK signing certificate differs from the persistent test key; publication refused\n' >&2
  exit 1
fi
printf 'Verified persistent APK signing certificate SHA256: %s\n' "$actual_certificate"
mkdir -p output
cp build/app/outputs/flutter-apk/app-profile.apk output/mtaxi-staging.apk
(cd output && sha256sum mtaxi-staging.apk > mtaxi-staging.apk.sha256)
printf 'Test APK built: %s/output/mtaxi-staging.apk\n' "$root_dir"
