#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-}"
max_mb="${MTAXI_SOURCE_ARCHIVE_MAX_MB:-500}"

fail() {
  echo "MTaxi source archive verification failed: $*" >&2
  exit 1
}

[ -n "$archive_path" ] || fail "usage: $0 mtaxi-source.tar.gz"
[ -f "$archive_path" ] || fail "archive not found: $archive_path"
case "$max_mb" in
  ''|*[!0-9]*) fail "MTAXI_SOURCE_ARCHIVE_MAX_MB must be an integer" ;;
esac

size_bytes="$(wc -c <"$archive_path" | tr -d ' ')"
max_bytes=$((max_mb * 1024 * 1024))
[ "$size_bytes" -le "$max_bytes" ] || fail "archive exceeds ${max_mb} MiB"

if [ -f "$archive_path.sha256" ]; then
  (
    cd "$(dirname "$archive_path")"
    shasum -a 256 -c "$(basename "$archive_path").sha256" >/dev/null
  ) ||
    fail "sha256 checksum mismatch"
fi

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT
tar -tzf "$archive_path" >"$tmp_list"

required_paths=(
  ARCHITECTURE_STATUS.md
  server/package.json
  server/package-lock.json
  server/.dockerignore
  server/db/schema.sql
  server/Dockerfile
  server/scripts/apply_schema.js
  server/scripts/backup_backend.js
  server/scripts/export_api_contract.js
  server/scripts/export_env_contract.js
  server/scripts/migrate_json_to_postgres.js
  server/scripts/monitor_backend.js
  server/scripts/preflight.js
  server/scripts/restore_backend.js
  server/scripts/seed_admin.js
  server/scripts/local_functional_smoke.js
  server/scripts/smoke_backend.js
  server/scripts/validate_production_deploy.js
  server/scripts/verify_backup_manifest.js
  docker-compose.production.yml
  deploy/nginx/mtaxi-api.conf
  deploy/ops_check.sh
  deploy/predeploy_check.sh
  deploy/systemd/mtaxi-backend.service
  deploy/systemd/mtaxi-backup.service
  deploy/systemd/mtaxi-backup.timer
  deploy/systemd/mtaxi-monitor.service
  deploy/systemd/mtaxi-monitor.timer
  deploy/vps_prereq_check.sh
  scripts/backend_migration_status.sh
  scripts/build_backend_release.sh
  scripts/check_backend_api_contract.sh
  scripts/check_backend_env_contract.sh
  scripts/check_backend_migration_ready.sh
  scripts/check_backend_migration_quick_status.sh
  scripts/check_backend_migration_small_steps.sh
  scripts/check_backend_transfer_steps.sh
  scripts/cleanup_output_handoffs.sh
  scripts/check_vps_cutover_runbook.sh
  scripts/check_client_backend_config.sh
  scripts/check_client_backend_only_static.sh
  scripts/check_firebase_fcm_only.sh
  scripts/check_local_flutter_commands.sh
  scripts/check_local_app_backend_wiring.sh
  scripts/check_local_backend_runbook.sh
  scripts/check_local_functional_smoke.sh
  scripts/check_latest_vps_handoff_current.sh
  scripts/check_latest_vps_handoff_pointer.sh
  scripts/check_output_handoffs.sh
  scripts/check_local_backend_contract.sh
  scripts/check_vps_inputs.sh
  scripts/check_local_json_backend.sh
  scripts/check_mobile_backend_artifact.sh
  scripts/check_release_ready.sh
  scripts/check_shell_script_permissions.sh
  scripts/check_vps_cutover_dry_run.sh
  scripts/check_vps_handoff_extract_smoke.sh
  scripts/check_vps_postdeploy.sh
  scripts/check_web_backend_artifact.sh
  scripts/generate_production_env.sh
  scripts/latest_vps_handoff.sh
  scripts/package_source_archive.sh
  scripts/package_vps_handoff.sh
  scripts/print_local_flutter_commands.sh
  scripts/print_vps_upload_commands.sh
  scripts/remote_backend_url_guard.sh
  scripts/start_local_backend.sh
  scripts/start_local_json_backend.sh
  scripts/stop_local_backend.sh
  scripts/verify_backend_migration_status.sh
  scripts/verify_source_archive.sh
  scripts/verify_vps_handoff.sh
  docs/backend_deployment_checklist.md
  docs/backend_migration_plan.md
  docs/backend_migration_small_steps.md
  docs/backend_transfer_steps.md
  docs/local_backend_runbook.md
  docs/vps_cutover_runbook.md
  docs/vps_inputs.template.env
  docs/vps_required_inputs.md
  lib/backend/backend_session.dart
  pubspec.yaml
)

for required in "${required_paths[@]}"; do
  grep -Fx "$required" "$tmp_list" >/dev/null ||
    fail "required source path is missing: $required"
done

forbidden_patterns=(
  '^build/'
  '^server/node_modules/'
  '^node_modules/'
  '^ios/Pods/'
  '^ios/build/'
  '^android/\.gradle/'
  '^android/local\.properties$'
  '^android/app/build/'
  '^ios/Flutter/Generated\.xcconfig$'
  '^ios/Flutter/flutter_export_environment\.sh$'
  '^server/\.env$'
  '^server/\.env\.generated$'
  '^server/data/'
  '^server/uploads/'
  '^server/backups/'
  '^firebase/'
  '^firebase\.json$'
  '^\.firebaserc$'
  '^firestore\.(rules|indexes\.json)$'
  '^storage\.rules$'
  '^private_keys/'
  '^AuthKey_.*\.p8$'
  '^android/key\.properties$'
  '\.keystore\.properties$'
  '\.signing\.properties$'
  '\.jks$'
  '\.keystore$'
  '\.p12$'
  '\.mobileprovision$'
  '\.aab$'
  '^output/'
  '(^|/)\.DS_Store$'
  '^\.playwright-cli/'
  '^\.playwright-mcp/'
  '\.log$'
  '\.apk$'
  '\.ipa$'
)

for pattern in "${forbidden_patterns[@]}"; do
  if grep -E "$pattern" "$tmp_list" >/dev/null; then
    fail "archive contains forbidden path matching: $pattern"
  fi
done

echo "MTaxi source archive verification passed: $archive_path"
