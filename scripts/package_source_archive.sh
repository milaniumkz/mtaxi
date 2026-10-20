#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${MTAXI_SOURCE_ARCHIVE_DIR:-$root_dir/output}"
max_mb="${MTAXI_SOURCE_ARCHIVE_MAX_MB:-500}"
stamp="$(date +%Y%m%d-%H%M%S)"
archive_path="${1:-$output_dir/mtaxi-source-$stamp.tar.gz}"

fail() {
  echo "MTaxi source archive failed: $*" >&2
  exit 1
}

case "$max_mb" in
  ''|*[!0-9]*) fail "MTAXI_SOURCE_ARCHIVE_MAX_MB must be an integer" ;;
esac

mkdir -p "$(dirname "$archive_path")"

include_paths=(
  android
  assets
  deploy
  docs
  ios
  lib
  scripts
  server
  test
  web
  analysis_options.yaml
  devtools_options.yaml
  docker-compose.backend.yml
  docker-compose.production.yml
  pubspec.lock
  pubspec.yaml
  README.md
  ARCHITECTURE_STATUS.md
)

existing_paths=()
for item in "${include_paths[@]}"; do
  [ -e "$root_dir/$item" ] && existing_paths+=("$item")
done

[ "${#existing_paths[@]}" -gt 0 ] || fail "no source paths found"

tar -czf "$archive_path" \
  --exclude='.DS_Store' \
  --exclude='.dart_tool' \
  --exclude='.flutter-plugins' \
  --exclude='.packages' \
  --exclude='build' \
  --exclude='android/.gradle' \
  --exclude='android/local.properties' \
  --exclude='android/app/build' \
  --exclude='ios/Flutter/Generated.xcconfig' \
  --exclude='ios/Flutter/flutter_export_environment.sh' \
  --exclude='ios/Flutter/ephemeral' \
  --exclude='ios/Pods' \
  --exclude='ios/build' \
  --exclude='server/node_modules' \
  --exclude='server/data' \
  --exclude='server/uploads' \
  --exclude='server/backups' \
  --exclude='firebase' \
  --exclude='firebase.json' \
  --exclude='.firebaserc' \
  --exclude='firestore.rules' \
  --exclude='firestore.indexes.json' \
  --exclude='storage.rules' \
  --exclude='server/.env' \
  --exclude='server/.env.generated' \
  --exclude='.playwright-cli' \
  --exclude='.playwright-mcp' \
  --exclude='*.log' \
  --exclude='node_modules' \
  --exclude='output' \
  --exclude='private_keys' \
  --exclude='AuthKey_*.p8' \
  --exclude='android/key.properties' \
  --exclude='*.keystore.properties' \
  --exclude='*.signing.properties' \
  --exclude='*.jks' \
  --exclude='*.keystore' \
  --exclude='*.p12' \
  --exclude='*.mobileprovision' \
  --exclude='*.aab' \
  --exclude='*.apk' \
  --exclude='*.ipa' \
  -C "$root_dir" \
  "${existing_paths[@]}"

size_bytes="$(wc -c <"$archive_path" | tr -d ' ')"
max_bytes=$((max_mb * 1024 * 1024))
if [ "$size_bytes" -gt "$max_bytes" ]; then
  rm -f "$archive_path"
  fail "archive exceeds ${max_mb} MiB"
fi

"$root_dir/scripts/verify_source_archive.sh" "$archive_path"

(
  cd "$(dirname "$archive_path")"
  shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)

echo "MTaxi source archive ready: $archive_path"
echo "Checksum: $archive_path.sha256"
echo "Size: $(( (size_bytes + 1024 * 1024 - 1) / 1024 / 1024 )) MiB"
