#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_file="$root_dir/lib/backend/backend_session.dart"
calls_file="$root_dir/lib/backend/backend_calls/backend_calls.dart"

fail() {
  echo "MTaxi client backend config check failed: $*" >&2
  exit 1
}

[ -f "$session_file" ] || fail "missing lib/backend/backend_session.dart"
[ -f "$calls_file" ] || fail "missing lib/backend/backend_calls/backend_calls.dart"

contains() {
  local file="$1"
  local expected="$2"
  local message="$3"
  grep -F "$expected" "$file" >/dev/null 2>&1 || fail "$message"
}

not_contains_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -E "$pattern" "$file" >/dev/null 2>&1; then
    fail "$message"
  fi
}

contains "$session_file" "'MTAXI_BACKEND_URL'" "missing MTAXI_BACKEND_URL dart define"
contains "$session_file" "defaultValue: 'http://localhost:8080'" \
  "client must default to local backend until real server is provided"
contains "$session_file" "'MTAXI_REQUIRE_REMOTE_BACKEND'" \
  "missing production remote backend requirement flag"
contains "$session_file" "defaultValue: false" \
  "local mode must not require remote backend"
contains "$session_file" "bool get isMTaxiBackendEnabled => true" \
  "client backend mode must stay always enabled"
contains "$session_file" "MTAXI_BACKEND_URL must use https when" \
  "missing production HTTPS backend guard"
contains "$session_file" "MTAXI_BACKEND_URL must be a public backend URL when" \
  "missing production public backend guard"
contains "$session_file" "host == '10.0.2.2'" \
  "missing Android emulator local backend detection"
contains "$session_file" "host.startsWith('192.168.')" \
  "missing LAN backend detection for release guard"
contains "$session_file" "host.startsWith('169.254.')" \
  "missing link-local backend detection for release guard"
contains "$session_file" "headers['Authorization'] = 'Bearer \$token';" \
  "backend session calls must send backend bearer token"
contains "$session_file" "Uri.parse('\$mtaxiBackendCallBasePath/call/\$name')" \
  "backend session calls must use POST /call/:name"

contains "$calls_file" "ensureMTaxiBackendUrlAllowed();" \
  "makeCloudCall must enforce backend URL guard"
contains "$calls_file" "Uri.parse('\$baseUrl/call/\$callName')" \
  "makeCloudCall must use backend POST /call/:name"
contains "$calls_file" "headers['Authorization'] = 'Bearer \$token';" \
  "makeCloudCall must send backend bearer token"
contains "$calls_file" "'X-MTaxi-Platform'" \
  "makeCloudCall must send runtime platform context"
contains "$calls_file" "await saveBackendUserFromResponse(result);" \
  "makeCloudCall must keep backend session user fresh"

not_contains_regex "$calls_file" "cloud_functions|FirebaseFunctions|HttpsCallable|firebase_auth|FirebaseAuth|cloud_firestore|FirebaseFirestore" \
  "backend call wrapper must not use Firebase Auth/Firestore/Functions fallback"
not_contains_regex "$session_file" "cloud_functions|FirebaseFunctions|HttpsCallable|firebase_auth|FirebaseAuth|cloud_firestore|FirebaseFirestore" \
  "backend session must not use Firebase Auth/Firestore/Functions fallback"

echo "MTaxi client backend config check passed"
