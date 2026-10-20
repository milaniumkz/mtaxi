#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
doc_path="$root_dir/docs/backend_transfer_steps.md"

fail() {
  echo "MTaxi backend transfer steps check failed: $*" >&2
  exit 1
}

[ -f "$doc_path" ] || fail "missing docs/backend_transfer_steps.md"

contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$doc_path" >/dev/null 2>&1 || fail "$message"
}

contains "Firebase остается только для FCM push-уведомлений" "missing Firebase FCM-only rule"
contains "docs/backend_migration_small_steps.md" "missing backend migration small steps reference"
contains "./scripts/check_backend_migration_ready.sh" "missing local readiness gate"
contains "./scripts/check_backend_migration_small_steps.sh" "missing backend migration small steps check"
contains "./scripts/check_vps_inputs.sh" "missing VPS inputs check"
contains "./scripts/package_vps_handoff.sh" "missing handoff packaging step"
contains "./scripts/verify_vps_handoff.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS" \
  "missing handoff verification step"
contains "./scripts/latest_vps_handoff.sh" "missing latest handoff helper"
contains "output/LATEST_MTAXI_VPS_HANDOFF.txt" "missing latest handoff pointer file"
contains "./scripts/check_output_handoffs.sh" "missing output handoff inventory check"
contains "./scripts/print_vps_upload_commands.sh" "missing VPS upload command helper"
contains "./scripts/check_backend_env_contract.sh" "missing backend env contract check"
contains "./scripts/check_vps_handoff_extract_smoke.sh" "missing VPS handoff extract smoke"
contains "./scripts/check_vps_cutover_dry_run.sh" "missing VPS cutover dry-run"
contains "./scripts/check_vps_cutover_runbook.sh" "missing VPS cutover runbook"
contains "./scripts/start_local_backend.sh" "missing local PostgreSQL backend start"
contains "./scripts/start_local_json_backend.sh" "missing local JSON backend fallback"
contains "./scripts/stop_local_backend.sh" "missing safe local backend stop"
contains "./scripts/print_local_flutter_commands.sh" "missing local Flutter command helper"
contains "./scripts/check_local_backend_contract.sh http://127.0.0.1:8080" \
  "missing local backend contract check"
contains "docker compose down -v" "missing warning about destructive Docker volume removal"
contains "MTAXI_BACKEND_URL=http://127.0.0.1:8080" "missing local web backend URL"
contains "MTAXI_BACKEND_URL=http://10.0.2.2:8080" "missing Android emulator backend URL"
contains "sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi" "missing VPS extraction step"
contains "./deploy/predeploy_check.sh" "missing predeploy check"
contains "sudo ./deploy/install_vps_units.sh" "missing systemd install step"
contains "./scripts/check_vps_postdeploy.sh" "missing postdeploy check"
contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web" \
  "missing production web build command"
contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh apk" \
  "missing production apk build command"
contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh ios" \
  "missing production ios build command"
contains "Не возвращать Firebase Auth" "missing Firebase Auth ban"
contains "Не возвращать Firestore" "missing Firestore ban"
contains "Не отправлять SMS напрямую из клиента" "missing client SMS ban"
contains "Локально готово примерно 99%" "missing readiness percent"

echo "MTaxi backend transfer steps check passed: $doc_path"
