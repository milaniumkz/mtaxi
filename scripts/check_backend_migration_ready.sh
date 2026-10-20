#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "MTaxi migration readiness: backend tests"
(cd "$root_dir/server" && npm test)

echo "MTaxi migration readiness: shell syntax"
bash -n \
  "$root_dir/deploy/install_vps_units.sh" \
  "$root_dir/deploy/predeploy_check.sh" \
  "$root_dir/deploy/ops_check.sh" \
  "$root_dir/deploy/vps_prereq_check.sh" \
  "$root_dir/scripts/build_backend_release.sh" \
  "$root_dir/scripts/backend_migration_status.sh" \
  "$root_dir/scripts/check_backend_migration_ready.sh" \
  "$root_dir/scripts/check_backend_migration_quick_status.sh" \
  "$root_dir/scripts/check_backend_api_contract.sh" \
  "$root_dir/scripts/check_backend_env_contract.sh" \
  "$root_dir/scripts/check_backend_migration_small_steps.sh" \
  "$root_dir/scripts/check_backend_transfer_steps.sh" \
  "$root_dir/scripts/cleanup_output_handoffs.sh" \
  "$root_dir/scripts/check_vps_cutover_runbook.sh" \
  "$root_dir/scripts/check_client_backend_only_static.sh" \
  "$root_dir/scripts/check_client_backend_config.sh" \
  "$root_dir/scripts/check_firebase_fcm_only.sh" \
  "$root_dir/scripts/check_local_flutter_commands.sh" \
  "$root_dir/scripts/check_local_app_backend_wiring.sh" \
  "$root_dir/scripts/check_local_backend_runbook.sh" \
  "$root_dir/scripts/check_local_functional_smoke.sh" \
  "$root_dir/scripts/check_latest_vps_handoff_current.sh" \
  "$root_dir/scripts/check_latest_vps_handoff_pointer.sh" \
  "$root_dir/scripts/check_output_handoffs.sh" \
  "$root_dir/scripts/check_local_backend_contract.sh" \
  "$root_dir/scripts/check_vps_inputs.sh" \
  "$root_dir/scripts/check_local_json_backend.sh" \
  "$root_dir/scripts/check_mobile_backend_artifact.sh" \
  "$root_dir/scripts/check_release_ready.sh" \
  "$root_dir/scripts/check_shell_script_permissions.sh" \
  "$root_dir/scripts/check_vps_cutover_dry_run.sh" \
  "$root_dir/scripts/check_vps_handoff_extract_smoke.sh" \
  "$root_dir/scripts/check_vps_postdeploy.sh" \
  "$root_dir/scripts/check_web_backend_artifact.sh" \
  "$root_dir/scripts/generate_production_env.sh" \
  "$root_dir/scripts/latest_vps_handoff.sh" \
  "$root_dir/scripts/package_source_archive.sh" \
  "$root_dir/scripts/package_vps_handoff.sh" \
  "$root_dir/scripts/print_local_flutter_commands.sh" \
  "$root_dir/scripts/print_vps_upload_commands.sh" \
  "$root_dir/scripts/remote_backend_url_guard.sh" \
  "$root_dir/scripts/start_local_backend.sh" \
  "$root_dir/scripts/start_local_json_backend.sh" \
  "$root_dir/scripts/stop_local_backend.sh" \
  "$root_dir/scripts/verify_backend_migration_status.sh" \
  "$root_dir/scripts/verify_source_archive.sh" \
  "$root_dir/scripts/verify_vps_handoff.sh"

echo "MTaxi migration readiness: shell script permissions"
"$root_dir/scripts/check_shell_script_permissions.sh"

echo "MTaxi migration readiness: node syntax"
node --check "$root_dir/server/scripts/backend_status.js"
node --check "$root_dir/server/scripts/export_api_contract.js"
node --check "$root_dir/server/scripts/export_env_contract.js"
node --check "$root_dir/server/scripts/local_functional_smoke.js"
node --check "$root_dir/server/scripts/verify_backup_manifest.js"

echo "MTaxi migration readiness: Firebase FCM-only guard"
"$root_dir/scripts/check_firebase_fcm_only.sh"

echo "MTaxi migration readiness: quick backend status"
"$root_dir/scripts/check_backend_migration_quick_status.sh" >/dev/null

echo "MTaxi migration readiness: client backend-only static check"
"$root_dir/scripts/check_client_backend_only_static.sh"

echo "MTaxi migration readiness: client backend config"
"$root_dir/scripts/check_client_backend_config.sh"

echo "MTaxi migration readiness: backend API contract"
"$root_dir/scripts/check_backend_api_contract.sh"

echo "MTaxi migration readiness: backend env contract"
"$root_dir/scripts/check_backend_env_contract.sh"

echo "MTaxi migration readiness: backend migration status report"
"$root_dir/scripts/backend_migration_status.sh" "$tmp_dir/READINESS_REPORT.json"
"$root_dir/scripts/verify_backend_migration_status.sh" "$tmp_dir/READINESS_REPORT.json"

echo "MTaxi migration readiness: backend transfer steps"
"$root_dir/scripts/check_backend_transfer_steps.sh"

echo "MTaxi migration readiness: backend migration small steps"
"$root_dir/scripts/check_backend_migration_small_steps.sh"

echo "MTaxi migration readiness: VPS cutover runbook"
"$root_dir/scripts/check_vps_cutover_runbook.sh"

echo "MTaxi migration readiness: local Flutter commands"
"$root_dir/scripts/check_local_flutter_commands.sh"

echo "MTaxi migration readiness: local app backend wiring"
"$root_dir/scripts/check_local_app_backend_wiring.sh"

echo "MTaxi migration readiness: local backend runbook"
"$root_dir/scripts/check_local_backend_runbook.sh"

echo "MTaxi migration readiness: output handoff inventory"
MTAXI_VPS_HANDOFF_SKIP_READY=true \
  "$root_dir/scripts/package_vps_handoff.sh" "$tmp_dir/output/mtaxi-vps-handoff-ready"
"$root_dir/scripts/check_output_handoffs.sh" "$tmp_dir/output"
"$root_dir/scripts/check_latest_vps_handoff_pointer.sh" "$tmp_dir/output"

echo "MTaxi migration readiness: VPS upload commands"
"$root_dir/scripts/print_vps_upload_commands.sh" "$tmp_dir/output/mtaxi-vps-handoff-ready" >/dev/null

echo "MTaxi migration readiness: VPS handoff extract smoke"
"$root_dir/scripts/check_vps_handoff_extract_smoke.sh" "$tmp_dir/output/mtaxi-vps-handoff-ready"

echo "MTaxi migration readiness: VPS cutover dry-run"
"$root_dir/scripts/check_vps_cutover_dry_run.sh" "$tmp_dir/output/mtaxi-vps-handoff-ready"

echo "MTaxi migration readiness: local JSON backend"
"$root_dir/scripts/check_local_json_backend.sh"

echo "MTaxi migration readiness: local functional smoke"
"$root_dir/scripts/check_local_functional_smoke.sh"

echo "MTaxi migration readiness: source archive"
MTAXI_SOURCE_ARCHIVE_DIR="$tmp_dir" "$root_dir/scripts/package_source_archive.sh"

echo "MTaxi migration readiness: VPS handoff package"
MTAXI_VPS_HANDOFF_SKIP_READY=true \
  "$root_dir/scripts/package_vps_handoff.sh" "$tmp_dir/vps-handoff"

echo "MTaxi migration readiness passed"
