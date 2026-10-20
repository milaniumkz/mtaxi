#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "MTaxi local Flutter command check failed: $*" >&2
  exit 1
}

check_output() {
  local base_url="$1"
  local expected_web="$2"
  local expected_android="$3"
  local output

  output="$("$root_dir/scripts/print_local_flutter_commands.sh" "$base_url")"

  printf '%s\n' "$output" | grep -F -- "web:     flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=$expected_web" >/dev/null 2>&1 ||
    fail "missing web command for $base_url"
  printf '%s\n' "$output" | grep -F -- "android: flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=$expected_android" >/dev/null 2>&1 ||
    fail "missing Android command for $base_url"
}

check_output "http://127.0.0.1:8080" "http://127.0.0.1:8080" "http://10.0.2.2:8080"
check_output "http://localhost:8080" "http://localhost:8080" "http://10.0.2.2:8080"
check_output "http://192.168.1.20:8080" "http://192.168.1.20:8080" "http://192.168.1.20:8080"

echo "MTaxi local Flutter command check passed"
