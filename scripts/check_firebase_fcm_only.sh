#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "MTaxi Firebase guard failed: $*" >&2
  exit 1
}

for package_name in \
  cloud_firestore \
  cloud_functions \
  firebase_auth \
  firebase_storage \
  firebase_crashlytics \
  firebase_performance \
  firebase_database
do
  if grep -R --line-number --include='pubspec.yaml' --include='pubspec.lock' --include='.flutter-plugins-dependencies' \
    "$package_name" "$root_dir" >/tmp/mtaxi-firebase-guard.$$ 2>/dev/null; then
    cat /tmp/mtaxi-firebase-guard.$$ >&2
    rm -f /tmp/mtaxi-firebase-guard.$$
    fail "forbidden Flutter Firebase package found: $package_name"
  fi
done
rm -f /tmp/mtaxi-firebase-guard.$$

for marker in \
  "package:cloud_firestore" \
  "package:cloud_functions" \
  "package:firebase_auth" \
  "package:firebase_storage" \
  "package:firebase_crashlytics" \
  "package:firebase_performance" \
  "package:firebase_database" \
  "FirebaseFirestore" \
  "FirebaseAuth" \
  "FirebaseStorage" \
  "FirebaseFunctions" \
  "FirebaseDatabase"
do
  if grep -R --line-number --include='*.dart' "$marker" "$root_dir/lib" >/tmp/mtaxi-firebase-guard.$$ 2>/dev/null; then
    cat /tmp/mtaxi-firebase-guard.$$ >&2
    rm -f /tmp/mtaxi-firebase-guard.$$
    fail "forbidden Firebase client marker found: $marker"
  fi
done
rm -f /tmp/mtaxi-firebase-guard.$$

node - "$root_dir/server/package.json" <<'NODE'
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const dependencies = {
  ...(pkg.dependencies || {}),
  ...(pkg.devDependencies || {}),
  ...(pkg.optionalDependencies || {}),
};
const directFirebase = Object.keys(dependencies).filter((name) =>
  name === "firebase" ||
  name.startsWith("@firebase/") ||
  (name.startsWith("firebase-") && name !== "firebase-admin")
);
if (directFirebase.length > 0) {
  console.error(`forbidden server Firebase dependency found: ${directFirebase.join(", ")}`);
  process.exit(1);
}
if (dependencies["firebase-admin"] == null) {
  console.error("firebase-admin must remain available for FCM push transport");
  process.exit(1);
}
NODE

while IFS= read -r -d '' file_path; do
  relative_path="${file_path#$root_dir/server/src/}"
  if [ "$relative_path" = "push_transport.js" ]; then
    continue
  fi
  if grep -n "firebase-admin" "$file_path" >/tmp/mtaxi-firebase-guard.$$ 2>/dev/null; then
    cat /tmp/mtaxi-firebase-guard.$$ >&2
    rm -f /tmp/mtaxi-firebase-guard.$$
    fail "firebase-admin is allowed only in server/src/push_transport.js"
  fi
done < <(find "$root_dir/server/src" -type f -name '*.js' -print0)
rm -f /tmp/mtaxi-firebase-guard.$$

echo "MTaxi Firebase guard passed: Firebase is limited to FCM push"
