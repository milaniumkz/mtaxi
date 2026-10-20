#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
doc_path="$root_dir/docs/vps_cutover_runbook.md"

fail() {
  echo "MTaxi VPS cutover runbook check failed: $*" >&2
  exit 1
}

[ -f "$doc_path" ] || fail "missing docs/vps_cutover_runbook.md"

contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$doc_path" >/dev/null 2>&1 || fail "$message"
}

contains "Firebase остается только для FCM push" "missing FCM-only rule"
contains "./scripts/check_backend_migration_ready.sh" "missing readiness gate"
contains "./scripts/package_vps_handoff.sh" "missing handoff package command"
contains "./scripts/latest_vps_handoff.sh" "missing latest handoff command"
contains "./scripts/check_vps_cutover_dry_run.sh" "missing cutover dry-run"
contains "./scripts/print_vps_upload_commands.sh" "missing upload command helper"
contains "shasum -a 256 -c mtaxi-source-*.tar.gz.sha256" "missing checksum verification"
contains "./verify_vps_handoff.sh ." "missing handoff verifier"
contains "sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi" "missing extraction command"
contains "./deploy/vps_prereq_check.sh" "missing VPS prereq check"
contains "./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env" "missing VPS input check"
contains "./scripts/generate_production_env.sh server/.env" "missing production env generation"
contains "./deploy/predeploy_check.sh" "missing predeploy check"
contains "sudo ./deploy/install_vps_units.sh" "missing systemd install"
contains "./scripts/check_vps_postdeploy.sh" "missing postdeploy check"
contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web" "missing web release build"
contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh apk" "missing apk release build"
contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh ios" "missing ios release build"
contains "npm run db:verify-backup" "missing backup verification"
contains "MTAXI_RESTORE_DRY_RUN=true npm run db:restore" "missing restore dry-run"
contains "Не возвращать Firebase Auth" "missing Firebase Auth ban"
contains "Не возвращать Firestore" "missing Firestore ban"
contains "Не отправлять SMS напрямую из клиента" "missing client SMS ban"
contains "Не собирать release с localhost" "missing local release ban"

echo "MTaxi VPS cutover runbook check passed: $doc_path"
