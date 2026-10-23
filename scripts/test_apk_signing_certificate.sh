#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/apk_signing_certificate.sh"
certificate="$(printf 'a%.0s' {1..64})"
other="$(printf 'b%.0s' {1..64})"
[[ "$(printf 'Signer #1 certificate SHA-256 digest: %s\n' "$certificate" | mtaxi_apk_certificate_sha256)" == "$certificate" ]]
[[ "$(printf 'V2 Signer: certificate SHA-256 digest: %s\nV3 Signer: certificate SHA-256 digest: %s\n' "$certificate" "$certificate" | mtaxi_apk_certificate_sha256)" == "$certificate" ]]
[[ "$(printf 'Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: %s\nSigner (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: %s\n' "$certificate" "$certificate" | mtaxi_apk_certificate_sha256)" == "$certificate" ]]
if printf 'Signer #1 certificate SHA-256 digest: %s\nSigner #2 certificate SHA-256 digest: %s\n' "$certificate" "$other" | mtaxi_apk_certificate_sha256; then
  echo 'Unexpected additional signer accepted' >&2; exit 1
fi
if printf 'Signer #1 public key SHA-256 digest: %s\n' "$certificate" | mtaxi_apk_certificate_sha256; then
  echo 'Public key fingerprint accepted as certificate' >&2; exit 1
fi
if printf '' | mtaxi_apk_certificate_sha256; then
  echo 'Empty signer output accepted' >&2; exit 1
fi
echo 'APK certificate parser: 6 checks passed'
