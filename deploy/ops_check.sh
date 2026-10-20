#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="${MTAXI_DEPLOY_DIR:-$(cd "$script_dir/.." && pwd)}"
base_url="${MTAXI_OPS_BASE_URL:-http://127.0.0.1:8080}"
expect_store="${MTAXI_OPS_EXPECT_STORE:-postgres}"
backup_dir="${MTAXI_OPS_BACKUP_DIR:-/var/backups/mtaxi}"
backup_max_age_hours="${MTAXI_OPS_BACKUP_MAX_AGE_HOURS:-36}"

failures=0

section() {
  printf '\n== %s ==\n' "$*"
}

ok() {
  printf 'OK %s\n' "$*"
}

warn() {
  printf 'WARN %s\n' "$*" >&2
}

fail() {
  printf 'FAIL %s\n' "$*" >&2
  failures=$((failures + 1))
}

if ! printf '%s' "$backup_max_age_hours" | grep -Eq '^[0-9]+$'; then
  fail "MTAXI_OPS_BACKUP_MAX_AGE_HOURS must be a non-negative integer"
  backup_max_age_hours=36
fi

run_optional() {
  local label="$1"
  shift
  section "$label"
  if "$@"; then
    ok "$label"
  else
    fail "$label"
  fi
}

section "files"
for file in \
  "$root_dir/docker-compose.production.yml" \
  "$root_dir/server/.env" \
  "$root_dir/server/package.json" \
  "$root_dir/deploy/systemd/mtaxi-backend.service" \
  "$root_dir/deploy/systemd/mtaxi-backup.service" \
  "$root_dir/deploy/systemd/mtaxi-backup.timer" \
  "$root_dir/deploy/systemd/mtaxi-monitor.service" \
  "$root_dir/deploy/systemd/mtaxi-monitor.timer"; do
  if [ -f "$file" ]; then
    ok "$file"
  else
    fail "missing $file"
  fi
done

if command -v systemctl >/dev/null 2>&1; then
  run_optional "systemd backend" systemctl is-active --quiet mtaxi-backend.service
  run_optional "systemd backup timer" systemctl is-active --quiet mtaxi-backup.timer
  run_optional "systemd monitor timer" systemctl is-active --quiet mtaxi-monitor.timer
else
  warn "systemctl not found; skipped systemd status"
fi

section "backup"
latest_backup=""
if [ -d "$backup_dir" ]; then
  latest_backup="$(find "$backup_dir" -maxdepth 1 -type f -name 'mtaxi-backup-*.json' -print | sort | tail -1)"
  if [ -n "$latest_backup" ]; then
    ok "latest backup manifest: $latest_backup"
    if command -v stat >/dev/null 2>&1; then
      backup_mtime="$(stat -c %Y "$latest_backup" 2>/dev/null || stat -f %m "$latest_backup" 2>/dev/null || true)"
      if [ -n "$backup_mtime" ]; then
        backup_age_hours=$(( ( $(date +%s) - backup_mtime ) / 3600 ))
        if [ "$backup_age_hours" -gt "$backup_max_age_hours" ]; then
          warn "latest backup is ${backup_age_hours}h old; expected <= ${backup_max_age_hours}h"
        else
          ok "latest backup age: ${backup_age_hours}h"
        fi
      fi
    fi
  else
    warn "no backup manifest found in $backup_dir"
  fi
else
  warn "backup directory not found: $backup_dir"
fi

if [ -n "$latest_backup" ]; then
  if [ -d "$root_dir/server" ] && command -v npm >/dev/null 2>&1; then
    section "backup manifest verification"
    (
      cd "$root_dir/server"
      npm run db:verify-backup -- "$latest_backup"
    ) || fail "npm run db:verify-backup"
  else
    warn "npm or server directory not found; skipped backup manifest verification"
  fi
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  section "docker compose ps"
  (cd "$root_dir" && docker compose -f docker-compose.production.yml ps) || fail "docker compose ps"
elif command -v docker >/dev/null 2>&1; then
  fail "docker compose is required"
else
  warn "docker not found; skipped docker compose ps"
fi

if command -v curl >/dev/null 2>&1; then
  run_optional "livez" curl -fsS "$base_url/livez"
  run_optional "readyz" curl -fsS "$base_url/readyz"
  run_optional "store health" curl -fsS \
    -X POST "$base_url/call/getStoreHealth" \
    -H 'Content-Type: application/json' \
    -d '{}'
else
  warn "curl not found; skipped HTTP checks"
fi

if [ -d "$root_dir/server" ] && command -v npm >/dev/null 2>&1; then
  section "npm monitor"
  (
    cd "$root_dir/server"
    MTAXI_MONITOR_BASE_URL="$base_url" \
    MTAXI_MONITOR_EXPECT_STORE="$expect_store" \
    npm run monitor
  ) || fail "npm run monitor"
else
  warn "npm or server directory not found; skipped monitor"
fi

if [ "$failures" -gt 0 ]; then
  echo "MTaxi ops check failed: $failures problem(s)" >&2
  exit 1
fi

echo "MTaxi ops check passed"
