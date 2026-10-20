#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
require_handoff="${MTAXI_QUICK_STATUS_REQUIRE_HANDOFF:-false}"
trap 'rm -rf "$tmp_dir"' EXIT

report_path="$tmp_dir/READINESS_REPORT.json"

echo "MTaxi quick backend status: readiness report"
"$root_dir/scripts/backend_migration_status.sh" "$report_path"
"$root_dir/scripts/verify_backend_migration_status.sh" "$report_path"

echo "MTaxi quick backend status: Firebase FCM-only guard"
"$root_dir/scripts/check_firebase_fcm_only.sh" >/dev/null

echo "MTaxi quick backend status: latest VPS handoff"
if latest_output="$("$root_dir/scripts/latest_vps_handoff.sh" 2>&1)"; then
  printf '%s\n' "$latest_output"
  "$root_dir/scripts/check_latest_vps_handoff_current.sh"
  "$root_dir/scripts/check_latest_vps_handoff_pointer.sh" >/dev/null
else
  printf '%s\n' "$latest_output" >&2
  if [ "$require_handoff" = "true" ]; then
    exit 1
  fi
  echo "MTaxi quick backend status: no verified output handoff yet; run ./scripts/package_vps_handoff.sh"
fi

echo "MTaxi quick backend status: 99% ready, waiting for real VPS/domain/env and production smoke"
