#!/usr/bin/env bash
set -euo pipefail

handoff_dir="${1:-.}"

fail() {
  echo "MTaxi VPS handoff verification failed: $*" >&2
  exit 1
}

[ -d "$handoff_dir" ] || fail "directory not found: $handoff_dir"

for required_command in awk basename find grep shasum wc; do
  command -v "$required_command" >/dev/null 2>&1 ||
    fail "$required_command is required"
done

manifest_path="$handoff_dir/HANDOFF_MANIFEST.json"
[ -f "$manifest_path" ] || fail "missing HANDOFF_MANIFEST.json"

manifest_value() {
  local key="$1"
  awk -v key="\"$key\"" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*:" {
      sub(/^[^:]*:[[:space:]]*/, "", $0)
      sub(/[[:space:]]*,[[:space:]]*$/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 ~ /^"/) {
        sub(/^"/, "", $0)
        sub(/"$/, "", $0)
        gsub(/\\"/, "\"", $0)
        gsub(/\\\\/, "\\", $0)
      }
      print $0
      found = 1
      exit
    }
    END {
      if (!found) exit 2
    }
  ' "$manifest_path"
}

type_value="$(manifest_value type)" || fail "invalid manifest type"
[ "$type_value" = "mtaxi-vps-handoff" ] || fail "unexpected manifest type: $type_value"

version_value="$(manifest_value version)" || fail "invalid manifest version"
[ "$version_value" = "1" ] || fail "unexpected manifest version: $version_value"

archive_name="$(manifest_value sourceArchive)" || fail "missing sourceArchive in manifest"
archive_sha="$(manifest_value sourceArchiveSha256)" || fail "missing sourceArchiveSha256 in manifest"
archive_size="$(manifest_value sourceArchiveSizeBytes)" || fail "missing sourceArchiveSizeBytes in manifest"
next_steps="$(manifest_value nextSteps)" || fail "missing nextSteps in manifest"
quick_commands="$(manifest_value quickCommands)" || fail "missing quickCommands in manifest"
status_file="$(manifest_value status)" || fail "missing status in manifest"
readiness_report="$(manifest_value readinessReport)" || fail "missing readinessReport in manifest"
api_contract="$(manifest_value apiContract)" || fail "missing apiContract in manifest"
env_contract="$(manifest_value envContract)" || fail "missing envContract in manifest"
verifier_name="$(manifest_value verifier)" || fail "missing verifier in manifest"
firebase_usage="$(manifest_value firebaseUsage)" || fail "missing firebaseUsage in manifest"
readiness_percent="$(manifest_value readinessPercent)" || fail "missing readinessPercent in manifest"
readiness_remaining="$(manifest_value readinessRemaining)" || fail "missing readinessRemaining in manifest"
manifest_text="$(cat "$manifest_path")"

case "$archive_name" in
  mtaxi-source-*.tar.gz) ;;
  *) fail "unexpected source archive name: $archive_name" ;;
esac

case "$archive_sha" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
  *) fail "invalid sourceArchiveSha256" ;;
esac

case "$archive_size" in
  ''|*[!0-9]*) fail "sourceArchiveSizeBytes must be an integer" ;;
esac

[ "$next_steps" = "DEPLOY_NEXT_STEPS.md" ] || fail "unexpected nextSteps: $next_steps"
[ "$quick_commands" = "HANDOFF_QUICK_COMMANDS.md" ] || fail "unexpected quickCommands: $quick_commands"
[ "$status_file" = "HANDOFF_STATUS.md" ] || fail "unexpected status: $status_file"
[ "$readiness_report" = "READINESS_REPORT.json" ] || fail "unexpected readinessReport: $readiness_report"
[ "$api_contract" = "API_CONTRACT.json" ] || fail "unexpected apiContract: $api_contract"
[ "$env_contract" = "ENV_CONTRACT.json" ] || fail "unexpected envContract: $env_contract"
[ "$verifier_name" = "verify_vps_handoff.sh" ] || fail "unexpected verifier: $verifier_name"
[ "$firebase_usage" = "FCM push only" ] || fail "unexpected firebaseUsage: $firebase_usage"
[ "$readiness_percent" = "99" ] || fail "unexpected readinessPercent: $readiness_percent"
[ "$readiness_remaining" = "real VPS/domain/env and production smoke" ] ||
  fail "unexpected readinessRemaining: $readiness_remaining"

for required_check in \
  "backend tests" \
  "shell syntax" \
  "JavaScript syntax" \
  "Firebase FCM-only guard" \
  "client backend-only static check" \
  "client backend config check" \
  "backend API contract verification" \
  "backend env contract verification" \
  "local backend contract check" \
  "local Flutter command helper" \
  "local backend runbook verification" \
  "local functional smoke" \
  "local JSON backend smoke" \
  "source archive verification" \
  "backend migration status report verification" \
  "backend migration small steps verification" \
  "backend transfer steps verification" \
  "VPS cutover runbook verification" \
  "latest VPS handoff helper verification" \
  "output handoff inventory verification" \
  "VPS upload command helper verification" \
  "VPS handoff extract smoke verification" \
  "VPS cutover dry-run verification" \
  "backup manifest verification script" \
  "VPS postdeploy check script" \
  "VPS handoff manifest/checksum verification"
do
  echo "$manifest_text" | grep -F "\"$required_check\"" >/dev/null 2>&1 ||
    fail "manifest missing verified check: $required_check"
done

archive_path="$handoff_dir/$archive_name"
[ -f "$archive_path" ] || fail "missing source archive: $archive_name"
[ -f "$archive_path.sha256" ] || fail "missing source archive checksum: $archive_name.sha256"
[ -f "$handoff_dir/$next_steps" ] || fail "missing next steps: $next_steps"
[ -f "$handoff_dir/$quick_commands" ] || fail "missing quick commands: $quick_commands"
[ -f "$handoff_dir/$status_file" ] || fail "missing status: $status_file"
[ -f "$handoff_dir/$readiness_report" ] || fail "missing readiness report: $readiness_report"
[ -f "$handoff_dir/$api_contract" ] || fail "missing API contract: $api_contract"
[ -f "$handoff_dir/$env_contract" ] || fail "missing env contract: $env_contract"
[ -f "$handoff_dir/$verifier_name" ] || fail "missing verifier: $verifier_name"

while IFS= read -r entry; do
  name="$(basename "$entry")"
  case "$name" in
    "$archive_name"|"$archive_name.sha256"|"HANDOFF_MANIFEST.json"|"$next_steps"|"$quick_commands"|"$status_file"|"$readiness_report"|"$api_contract"|"$env_contract"|"$verifier_name") ;;
    *) fail "unexpected handoff file: $name" ;;
  esac
done < <(find "$handoff_dir" -mindepth 1 -maxdepth 1 -print)

status_path="$handoff_dir/$status_file"
report_path="$handoff_dir/$readiness_report"
api_contract_path="$handoff_dir/$api_contract"
env_contract_path="$handoff_dir/$env_contract"
next_steps_path="$handoff_dir/$next_steps"
quick_commands_path="$handoff_dir/$quick_commands"

status_contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$status_path" >/dev/null 2>&1 || fail "$message"
}

status_contains "ready for VPS cutover, pending real server inputs" \
  "status file does not describe pending VPS inputs"
status_contains "Readiness: 99% locally ready; final 1% requires real VPS/domain/env and production smoke." \
  "status file does not describe readiness percent"
status_contains "JavaScript syntax" \
  "status file does not list JavaScript syntax check"
status_contains "Firebase FCM-only guard" \
  "status file does not list Firebase FCM-only guard"
status_contains "Client backend-only static check" \
  "status file does not list client backend-only static check"
status_contains "Client backend config check" \
  "status file does not list client backend config check"
status_contains "Backend API contract verification" \
  "status file does not list backend API contract verification"
status_contains "Backend env contract verification" \
  "status file does not list backend env contract verification"
status_contains "Local backend contract check" \
  "status file does not list local backend contract check"
status_contains "Local Flutter command helper" \
  "status file does not list local Flutter command helper"
status_contains "Local backend runbook verification" \
  "status file does not list local backend runbook verification"
status_contains "Local functional smoke" \
  "status file does not list local functional smoke"
status_contains "Backend migration status report verification" \
  "status file does not list backend migration status report verification"
status_contains "Backend migration small steps verification" \
  "status file does not list backend migration small steps verification"
status_contains "Backend transfer steps verification" \
  "status file does not list backend transfer steps verification"
status_contains "VPS cutover runbook verification" \
  "status file does not list VPS cutover runbook verification"
status_contains "Latest VPS handoff helper verification" \
  "status file does not list latest VPS handoff helper verification"
status_contains "Output handoff inventory verification" \
  "status file does not list output handoff inventory verification"
status_contains "VPS upload command helper verification" \
  "status file does not list VPS upload command helper verification"
status_contains "VPS handoff extract smoke verification" \
  "status file does not list VPS handoff extract smoke verification"
status_contains "VPS cutover dry-run verification" \
  "status file does not list VPS cutover dry-run verification"
status_contains "VPS SSH access" \
  "status file does not list VPS SSH access"
status_contains "API domain and DNS" \
  "status file does not list API domain and DNS"
status_contains 'Production `server/.env`' \
  "status file does not list production server env"
status_contains "Real SMS provider" \
  "status file does not list real SMS provider"
status_contains "Real payment provider" \
  "status file does not list real payment provider"
status_contains "FCM service account for push only" \
  "status file does not list FCM push credentials"
status_contains "Production smoke/monitor after deployment" \
  "status file does not mention production smoke/monitor"
status_contains "Firebase must stay limited to FCM push" \
  "status file does not keep Firebase limited to FCM push"

report_contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$report_path" >/dev/null 2>&1 || fail "$message"
}

report_contains '"type": "mtaxi-backend-migration-status"' \
  "readiness report has wrong type"
report_contains '"readinessPercent": 99' \
  "readiness report does not pin readiness percent"
report_contains '"architecture": "backend-only"' \
  "readiness report does not describe backend-only architecture"
report_contains '"firebaseUsage": "FCM push only"' \
  "readiness report does not keep Firebase limited to FCM push"
report_contains 'Production postdeploy smoke and monitor' \
  "readiness report does not list production smoke"

api_contract_contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$api_contract_path" >/dev/null 2>&1 || fail "$message"
}

api_contract_contains '"type": "mtaxi-backend-api-contract"' \
  "API contract has wrong type"
api_contract_contains '"endpoint": "POST /call/:name"' \
  "API contract has wrong endpoint"
api_contract_contains '"firebaseUsage": "FCM push only"' \
  "API contract does not keep Firebase limited to FCM push"
api_contract_contains '"missingServerHandlers": []' \
  "API contract reports missing server handlers"
api_contract_contains '"name": "createPassengerOrder"' \
  "API contract does not list createPassengerOrder"
api_contract_contains '"name": "adminManageOrder"' \
  "API contract does not list adminManageOrder"

env_contract_contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$env_contract_path" >/dev/null 2>&1 || fail "$message"
}

env_contract_contains '"type": "mtaxi-backend-env-contract"' \
  "env contract has wrong type"
env_contract_contains '"store": "PostgreSQL in production"' \
  "env contract does not require PostgreSQL in production"
env_contract_contains '"firebaseUsage": "FCM push only"' \
  "env contract does not keep Firebase limited to FCM push"
env_contract_contains '"NODE_ENV": "production"' \
  "env contract does not pin NODE_ENV production"
env_contract_contains '"MTAXI_STORE": "postgres"' \
  "env contract does not pin PostgreSQL store"
env_contract_contains '"MTAXI_SMS_PROVIDER": "http"' \
  "env contract does not pin HTTP SMS provider"
env_contract_contains '"MTAXI_PAYMENT_PROVIDER": "redirect"' \
  "env contract does not pin redirect payment provider"
env_contract_contains '"MTAXI_FCM_ENABLED": "true"' \
  "env contract does not enable FCM push"
env_contract_contains '"MTAXI_ALLOW_LOCAL_SMS"' \
  "env contract does not forbid local SMS flag"
env_contract_contains '"MTAXI_ALLOW_LOCAL_PAYMENT"' \
  "env contract does not forbid local payment flag"
env_contract_contains '"MTAXI_ALLOW_SIMULATED_PUSH"' \
  "env contract does not forbid simulated push flag"
env_contract_contains '"missingInExample": []' \
  "env contract reports missing env example keys"
env_contract_contains '"mismatchedProductionDefaults": []' \
  "env contract reports production default drift"
env_contract_contains '"unsafeDevDefaults": []' \
  "env contract reports unsafe dev defaults"

next_steps_contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$next_steps_path" >/dev/null 2>&1 || fail "$message"
}

next_steps_contains "/tmp/mtaxi-handoff" \
  "next steps do not use /tmp/mtaxi-handoff"
next_steps_contains "chmod +x verify_vps_handoff.sh" \
  "next steps do not make bundled verifier executable"
next_steps_contains "HANDOFF_QUICK_COMMANDS.md" \
  "next steps do not reference quick commands"
next_steps_contains "API_CONTRACT.json" \
  "next steps do not mention API contract"
next_steps_contains "ENV_CONTRACT.json" \
  "next steps do not mention env contract"
next_steps_contains "shasum -a 256 -c mtaxi-source-*.tar.gz.sha256" \
  "next steps do not verify source archive checksum"
next_steps_contains "./verify_vps_handoff.sh ." \
  "next steps do not verify handoff before extraction"
next_steps_contains "sudo mkdir -p /opt/mtaxi" \
  "next steps do not create /opt/mtaxi"
next_steps_contains "sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi" \
  "next steps do not extract source archive to /opt/mtaxi"
next_steps_contains "cd /opt/mtaxi" \
  "next steps do not enter /opt/mtaxi"
next_steps_contains "docs/backend_transfer_steps.md" \
  "next steps do not reference backend transfer steps"
next_steps_contains "docs/backend_migration_small_steps.md" \
  "next steps do not reference backend migration small steps"
next_steps_contains "./scripts/check_backend_migration_small_steps.sh" \
  "next steps do not verify backend migration small steps"
next_steps_contains "./scripts/check_backend_api_contract.sh" \
  "next steps do not verify backend API contract"
next_steps_contains "./scripts/check_backend_env_contract.sh" \
  "next steps do not verify backend env contract"
next_steps_contains "./scripts/check_backend_transfer_steps.sh" \
  "next steps do not verify backend transfer steps"
next_steps_contains "./scripts/check_vps_cutover_runbook.sh" \
  "next steps do not verify VPS cutover runbook"
next_steps_contains "./scripts/check_local_flutter_commands.sh" \
  "next steps do not verify local Flutter commands"
next_steps_contains "./scripts/check_local_backend_runbook.sh" \
  "next steps do not verify local backend runbook"
next_steps_contains "./scripts/check_local_functional_smoke.sh" \
  "next steps do not verify local functional smoke"
next_steps_contains "./scripts/check_output_handoffs.sh output" \
  "next steps do not verify output handoff inventory"
next_steps_contains "cp docs/vps_inputs.template.env /tmp/mtaxi-vps-inputs.env" \
  "next steps do not copy VPS inputs template"
next_steps_contains "./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env" \
  "next steps do not verify VPS inputs"
next_steps_contains "./scripts/generate_production_env.sh server/.env" \
  "next steps do not generate production env"
next_steps_contains "./deploy/predeploy_check.sh" \
  "next steps do not run predeploy check"
next_steps_contains "sudo ./deploy/install_vps_units.sh" \
  "next steps do not install VPS systemd units"
next_steps_contains "sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer" \
  "next steps do not start backend, backup and monitor units"
next_steps_contains "./scripts/check_vps_postdeploy.sh" \
  "next steps do not run postdeploy gate"
next_steps_contains "MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web|apk|ios" \
  "next steps do not require release builds against production backend"
next_steps_contains "Firebase is allowed only for FCM push" \
  "next steps do not keep Firebase limited to FCM push"

quick_commands_contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$quick_commands_path" >/dev/null 2>&1 || fail "$message"
}

quick_commands_contains "MTAXI_VPS_USER" \
  "quick commands do not define VPS user"
quick_commands_contains "MTAXI_VPS_HOST" \
  "quick commands do not define VPS host"
quick_commands_contains "./scripts/latest_vps_handoff.sh" \
  "quick commands do not select latest handoff"
quick_commands_contains 'scp "$LATEST_HANDOFF"/*' \
  "quick commands do not upload handoff files"
quick_commands_contains "./verify_vps_handoff.sh ." \
  "quick commands do not verify handoff"
quick_commands_contains "sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi" \
  "quick commands do not extract source to /opt/mtaxi"
quick_commands_contains "./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env" \
  "quick commands do not verify VPS inputs"
quick_commands_contains "./scripts/check_vps_postdeploy.sh" \
  "quick commands do not run postdeploy check"
quick_commands_contains 'MTAXI_BACKEND_URL="$MTAXI_API_URL" ./scripts/build_backend_release.sh web|apk|ios' \
  "quick commands do not build releases against production backend"
quick_commands_contains "Firebase is allowed only for FCM push" \
  "quick commands do not keep Firebase limited to FCM push"

actual_size="$(wc -c <"$archive_path" | tr -d ' ')"
[ "$actual_size" = "$archive_size" ] || fail "manifest archive size mismatch"

actual_sha="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
[ "$actual_sha" = "$archive_sha" ] || fail "manifest sha256 mismatch"

(cd "$handoff_dir" && shasum -a 256 -c "$archive_name.sha256" >/dev/null) ||
  fail "source archive checksum failed"

echo "MTaxi VPS handoff verification passed: $handoff_dir"
