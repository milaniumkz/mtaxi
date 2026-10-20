#!/usr/bin/env bash
set -euo pipefail

report_path="${1:-}"

fail() {
  echo "MTaxi backend migration status verification failed: $*" >&2
  exit 1
}

[ -n "$report_path" ] || fail "usage: $0 READINESS_REPORT.json"
[ -f "$report_path" ] || fail "report not found: $report_path"

contains() {
  local expected="$1"
  local message="$2"
  grep -F "$expected" "$report_path" >/dev/null 2>&1 || fail "$message"
}

contains '"type": "mtaxi-backend-migration-status"' "wrong report type"
contains '"version": 1' "wrong report version"
contains '"readinessPercent": 99' "readiness percent must stay 99 before production smoke"
contains '"architecture": "backend-only"' "architecture must be backend-only"
contains '"firebaseUsage": "FCM push only"' "Firebase must stay FCM-only"
contains '"backend tests"' "missing backend tests evidence"
contains '"client backend-only static check"' "missing client backend-only evidence"
contains '"client backend config check"' "missing client backend config evidence"
contains '"backend API contract verification"' "missing backend API contract evidence"
contains '"backend env contract verification"' "missing backend env contract evidence"
contains '"local backend contract check"' "missing local backend contract evidence"
contains '"local Flutter command helper"' "missing local Flutter command helper evidence"
contains '"local backend runbook verification"' "missing local backend runbook evidence"
contains '"local functional smoke"' "missing local functional smoke evidence"
contains '"local JSON backend smoke"' "missing local smoke evidence"
contains '"backend migration status report verification"' "missing status report verification evidence"
contains '"backend migration small steps verification"' "missing backend migration small steps evidence"
contains '"backend transfer steps verification"' "missing transfer steps verification evidence"
contains '"VPS cutover runbook verification"' "missing VPS cutover runbook evidence"
contains '"latest VPS handoff helper verification"' "missing latest handoff helper evidence"
contains '"output handoff inventory verification"' "missing output handoff inventory evidence"
contains '"VPS upload command helper verification"' "missing VPS upload command helper evidence"
contains '"VPS handoff extract smoke verification"' "missing VPS handoff extract smoke evidence"
contains '"VPS cutover dry-run verification"' "missing VPS cutover dry-run evidence"
contains '"Step-by-step transfer document"' "missing step-by-step transfer document evidence"
contains '"VPS SSH access"' "missing VPS requirement"
contains '"Production server/.env"' "missing production env requirement"
contains '"Production postdeploy smoke and monitor"' "missing production smoke requirement"
contains 'Do not mark 100% until real VPS/domain/env are configured and production postdeploy smoke passes.' \
  "missing completion rule"

echo "MTaxi backend migration status verification passed: $report_path"
