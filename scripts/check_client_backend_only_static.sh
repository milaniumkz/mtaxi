#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "MTaxi client backend-only static check failed: $*" >&2
  exit 1
}

allowed_flutter_firebase_plugins=(
  firebase_core
  firebase_core_platform_interface
  firebase_core_web
  firebase_messaging
  firebase_messaging_platform_interface
  firebase_messaging_web
)

allowed_native_firebase_plugins=(
  firebase_core
  firebase_messaging
)

is_allowed() {
  local value="$1"
  shift
  local allowed
  for allowed in "$@"; do
    [ "$value" = "$allowed" ] && return 0
  done
  return 1
}

require_file() {
  [ -f "$root_dir/$1" ] || fail "missing required file: $1"
}

require_file pubspec.yaml
require_file pubspec.lock
require_file .flutter-plugins-dependencies
require_file lib/backend/backend.dart
require_file lib/backend/backend_session.dart

for dep in \
  cloud_firestore \
  cloud_functions \
  firebase_auth \
  firebase_crashlytics \
  firebase_database \
  firebase_performance \
  firebase_storage \
  google_sign_in \
  sign_in_with_apple; do
  if grep -Eq "^[[:space:]]{2}${dep}:" "$root_dir/pubspec.yaml" "$root_dir/pubspec.lock"; then
    fail "forbidden client dependency is present: $dep"
  fi
done

while IFS= read -r package; do
  [ -n "$package" ] || continue
  is_allowed "$package" "${allowed_flutter_firebase_plugins[@]}" ||
    fail "unexpected Flutter Firebase/cloud package: $package"
done < <(
  awk '/^  (firebase_|cloud_)[a-z_]+:/{gsub(":", "", $1); print $1}' \
    "$root_dir/pubspec.lock" | sort -u
)

while IFS= read -r plugin; do
  [ -n "$plugin" ] || continue
  is_allowed "$plugin" "${allowed_flutter_firebase_plugins[@]}" ||
    fail "unexpected generated Flutter plugin: $plugin"
done < <(
  grep -Eo '"name":"(firebase_|cloud_)[^"]+"' \
    "$root_dir/.flutter-plugins-dependencies" |
    sed -E 's/^"name":"([^"]+)"$/\1/' | sort -u
)

for marker in \
  'package:cloud_firestore/' \
  'package:cloud_functions/' \
  'package:firebase_auth/' \
  'package:firebase_crashlytics/' \
  'package:firebase_database/' \
  'package:firebase_performance/' \
  'package:firebase_storage/' \
  '/backend/cloud_functions/' \
  '/backend/firebase_storage/' \
  FirebaseFirestore \
  FirebaseAuth \
  FirebaseStorage \
  FirestoreRecord \
  FFFirestorePage \
  FFFirebaseStruct \
  firestore_util.dart \
  functions.net \
  run.app; do
  if grep -R -n -F --include='*.dart' "$marker" "$root_dir/lib" >/dev/null; then
    fail "forbidden client marker is present in lib/: $marker"
  fi
done

if grep -F "package:firebase_core/firebase_core.dart" "$root_dir/lib/backend/backend.dart" >/dev/null; then
  fail "firebase_core must stay scoped to FCM init, not exported from lib/backend/backend.dart"
fi

while IFS=: read -r path _line _rest; do
  rel_path="${path#"$root_dir/"}"
  case "$rel_path" in
    lib/main.dart|lib/backend/push_notifications/*.dart) ;;
    *) fail "firebase_messaging import must stay scoped to push notifications: $rel_path" ;;
  esac
done < <(
  grep -R -n -F "package:firebase_messaging/firebase_messaging.dart" \
    "$root_dir/lib" --include='*.dart' || true
)

while IFS=: read -r path _line _rest; do
  rel_path="${path#"$root_dir/"}"
  case "$rel_path" in
    lib/backend/firebase/firebase_config.dart) ;;
    *) fail "firebase_core import must stay scoped to Firebase init: $rel_path" ;;
  esac
done < <(
  grep -R -n -F "package:firebase_core/firebase_core.dart" \
    "$root_dir/lib" --include='*.dart' || true
)

for marker in \
  '.snapshots()' \
  '.count()'; do
  if grep -F "$marker" "$root_dir/lib/backend/backend.dart" >/dev/null; then
    fail "legacy FlutterFlow query helper keeps old Firebase read marker: $marker"
  fi
done

while IFS= read -r offender; do
  [ -z "$offender" ] || fail "generated record model keeps old Firebase document read: $offender"
done < <(
  grep -R -n -E 'ref\.(snapshots|get)\(\)' \
    "$root_dir/lib/backend/schema" --include='*_record.dart' || true
)

admin_collection="$root_dir/lib/admin/admin_collection/admin_collection_widget.dart"
if [ -f "$admin_collection" ]; then
  for marker in \
    '.snapshots()' \
    'reference.set(' \
    '.add(converted)' \
    'reference.delete()' \
    'BackendRefs.instance.collection(collectionName)'; do
    if grep -F "$marker" "$admin_collection" >/dev/null; then
      fail "admin collection keeps old Firebase fallback marker: $marker"
    fi
  done
fi

generated_native_files=(
  android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
  ios/Runner/GeneratedPluginRegistrant.m
  ios/Runner/GeneratedPluginRegistrant.h
)

for path in "${generated_native_files[@]}"; do
  [ -f "$root_dir/$path" ] || continue
  for marker in \
    FirebaseAuth \
    FirebaseFirestore \
    FirebaseFunctions \
    FirebaseStorage \
    FirebaseCrashlytics \
    FirebasePerformance \
    cloud_firestore \
    cloud_functions \
    firebase_auth \
    firebase_crashlytics \
    firebase_database \
    firebase_performance \
    firebase_storage; do
    if grep -F "$marker" "$root_dir/$path" >/dev/null; then
      fail "forbidden native marker is present in $path: $marker"
    fi
  done

  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    is_allowed "$plugin" "${allowed_native_firebase_plugins[@]}" ||
      fail "unexpected native Firebase plugin in $path: $plugin"
  done < <(grep -Eo 'firebase_[a-z_]+' "$root_dir/$path" | sort -u)
done

if [ -f "$root_dir/ios/Podfile.lock" ]; then
  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    is_allowed "$plugin" "${allowed_native_firebase_plugins[@]}" ||
      fail "unexpected iOS Firebase plugin in Podfile.lock: $plugin"
  done < <(
    sed -n -E 's/^[[:space:]]*- (firebase_[a-z_]+).*/\1/p' \
      "$root_dir/ios/Podfile.lock" | sort -u
  )
fi

for path in android/app/google-services.json ios/Runner/GoogleService-Info.plist; do
  [ -f "$root_dir/$path" ] || continue
  for marker in \
    STORAGE_BUCKET \
    storage_bucket \
    authDomain \
    DATABASE_URL \
    '<key>IS_SIGNIN_ENABLED</key>' \
    '<key>IS_APPINVITE_ENABLED</key>'; do
    if grep -F "$marker" "$root_dir/$path" >/dev/null; then
      fail "Firebase native config must stay FCM-only: $path contains $marker"
    fi
  done
done

echo "MTaxi client backend-only static check passed"
