#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
doc_path="$root_dir/docs/backend_migration_small_steps.md"

fail() {
  echo "MTaxi backend migration small steps check failed: $*" >&2
  exit 1
}

[ -f "$doc_path" ] || fail "missing docs/backend_migration_small_steps.md"

contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$doc_path" >/dev/null 2>&1 || fail "$message"
}

contains "Firebase разрешен только для FCM push" "missing Firebase FCM-only rule"
contains "Firebase Auth не использовать" "missing Firebase Auth ban"
contains "Firestore не использовать" "missing Firestore ban"
contains "Firebase Cloud Functions не использовать" "missing Cloud Functions ban"
contains "Firebase Storage не использовать" "missing Firebase Storage ban"
contains "SMS не отправлять с клиента" "missing client SMS ban"
contains "./scripts/check_backend_migration_ready.sh" "missing readiness gate"
contains "./scripts/check_backend_api_contract.sh" "missing backend API contract check"
contains "./scripts/check_backend_env_contract.sh" "missing backend env contract check"
contains "./scripts/check_client_backend_config.sh" "missing client backend config check"
contains "./scripts/start_local_backend.sh" "missing local PostgreSQL backend"
contains "./scripts/start_local_json_backend.sh" "missing JSON fallback backend"
contains "./scripts/check_local_backend_contract.sh http://127.0.0.1:8080" "missing local backend contract check"
contains "./scripts/check_local_backend_runbook.sh" "missing local backend runbook check"
contains "./scripts/check_local_functional_smoke.sh" "missing local functional smoke"
contains "MTAXI_BACKEND_URL=http://127.0.0.1:8080" "missing local web backend URL"
contains "MTAXI_BACKEND_URL=http://10.0.2.2:8080" "missing Android emulator backend URL"
contains "./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env" "missing VPS input check"
contains "./scripts/package_vps_handoff.sh" "missing handoff packaging"
contains "./scripts/latest_vps_handoff.sh" "missing latest handoff helper"
contains "./scripts/check_output_handoffs.sh" "missing output handoff check"
contains "./scripts/verify_vps_handoff.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS" "missing handoff verifier"
contains "./scripts/check_vps_handoff_extract_smoke.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS" "missing extract smoke"
contains "./scripts/check_vps_cutover_dry_run.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS" "missing cutover dry-run"
contains "./scripts/print_vps_upload_commands.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS" "missing VPS upload command helper"
contains "sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi" "missing VPS extraction"
contains "./deploy/vps_prereq_check.sh" "missing VPS prerequisite check"
contains "./scripts/generate_production_env.sh server/.env" "missing production env generation"
contains "./deploy/predeploy_check.sh" "missing predeploy check"
contains "sudo ./deploy/install_vps_units.sh" "missing systemd install"
contains "./scripts/check_vps_postdeploy.sh" "missing postdeploy check"
contains "./scripts/check_release_ready.sh" "missing release readiness check"
contains "./scripts/build_backend_release.sh web" "missing web release build"
contains "./scripts/build_backend_release.sh apk" "missing apk release build"
contains "./scripts/build_backend_release.sh ios" "missing ios release build"
contains "Финальные 100% ставить только после реального VPS" "missing completion rule"

echo "MTaxi backend migration small steps check passed: $doc_path"
