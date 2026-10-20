#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
doc_path="$root_dir/docs/local_backend_runbook.md"

fail() {
  echo "MTaxi local backend runbook check failed: $*" >&2
  exit 1
}

[ -f "$doc_path" ] || fail "missing docs/local_backend_runbook.md"

contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$doc_path" >/dev/null 2>&1 || fail "$message"
}

contains "Firebase в этом режиме разрешен только для FCM push" "missing Firebase FCM-only rule"
contains "./scripts/check_backend_migration_quick_status.sh" "missing quick status"
contains "./scripts/check_backend_migration_ready.sh" "missing full readiness"
contains "./scripts/start_local_backend.sh" "missing local PostgreSQL backend"
contains "./scripts/start_local_json_backend.sh" "missing JSON fallback backend"
contains "curl -fsS http://127.0.0.1:8080/readyz" "missing readyz check"
contains "./scripts/check_local_backend_contract.sh http://127.0.0.1:8080" "missing local contract check"
contains "./scripts/check_local_functional_smoke.sh" "missing local functional smoke"
contains "./scripts/print_local_flutter_commands.sh http://127.0.0.1:8080" "missing Flutter command helper"
contains "MTAXI_BACKEND_URL=http://127.0.0.1:8080" "missing web backend URL"
contains "MTAXI_BACKEND_URL=http://10.0.2.2:8080" "missing Android emulator backend URL"
contains "MTAXI_REQUIRE_REMOTE_BACKEND=true" "missing release flag warning"
contains "Восстановление активного заказа после обновления страницы" "missing active order recovery scenario"
contains 'Не использовать `docker compose down -v`' "missing destructive Docker warning"
contains "Не возвращать Firebase Auth" "missing Firebase Auth ban"
contains "Не возвращать Firestore" "missing Firestore ban"
contains "Не отправлять SMS напрямую из клиента" "missing client SMS ban"

echo "MTaxi local backend runbook check passed: $doc_path"
