#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "MTaxi local app backend wiring check failed: $*" >&2
  exit 1
}

require_file() {
  [ -f "$root_dir/$1" ] || fail "missing required file: $1"
}

contains() {
  local file="$1"
  local expected="$2"
  local message="$3"
  grep -F "$expected" "$root_dir/$file" >/dev/null 2>&1 || fail "$message"
}

require_file lib/backend/backend_session.dart
require_file lib/backend/backend_calls/backend_calls.dart
require_file scripts/print_local_flutter_commands.sh
require_file docs/local_backend_runbook.md

contains lib/backend/backend_session.dart "'MTAXI_BACKEND_URL'" \
  "backend_session.dart must read MTAXI_BACKEND_URL"
contains lib/backend/backend_session.dart "defaultValue: 'http://localhost:8080'" \
  "local backend default must stay http://localhost:8080"
contains lib/backend/backend_session.dart "'MTAXI_REQUIRE_REMOTE_BACKEND'" \
  "backend_session.dart must expose release remote-backend guard"
contains lib/backend/backend_session.dart "ensureMTaxiBackendUrlAllowed();" \
  "backend calls must run backend URL guard before HTTP"
contains lib/backend/backend_session.dart "Uri.parse('\$mtaxiBackendCallBasePath/call/\$name')" \
  "backend_session.dart must call /call/:name"

contains lib/backend/backend_calls/backend_calls.dart "Future<Map<String, dynamic>> makeCloudCall(" \
  "makeCloudCall compatibility wrapper is missing"
contains lib/backend/backend_calls/backend_calls.dart "Uri.parse('\$baseUrl/call/\$callName')" \
  "makeCloudCall must call MTaxi backend /call/:name"
contains lib/backend/backend_calls/backend_calls.dart "ensureMTaxiBackendUrlAllowed();" \
  "makeCloudCall must run backend URL guard"
contains lib/backend/backend_calls/backend_calls.dart "headers['Authorization'] = 'Bearer \$token';" \
  "makeCloudCall must pass backend bearer token"

commands_output="$("$root_dir/scripts/print_local_flutter_commands.sh" http://127.0.0.1:8080)"
printf '%s\n' "$commands_output" | grep -F "flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080" >/dev/null 2>&1 ||
  fail "local web command must point to 127.0.0.1"
printf '%s\n' "$commands_output" | grep -F "flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080" >/dev/null 2>&1 ||
  fail "local Android command must point to 10.0.2.2"

contains docs/local_backend_runbook.md "flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080" \
  "local backend runbook must document web backend URL"
contains docs/local_backend_runbook.md "flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080" \
  "local backend runbook must document Android emulator backend URL"
contains docs/local_backend_runbook.md "Для release использовать только внешний \`https://\` backend." \
  "local backend runbook must forbid local release backend"

echo "MTaxi local app backend wiring check passed"
