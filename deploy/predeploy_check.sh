#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

fail() {
  echo "MTaxi predeploy check failed: $*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing required file: $1"
}

require_executable() {
  require_file "$1"
  [ -x "$1" ] || fail "required script is not executable: $1"
}

require_file "server/.env"
require_file "docker-compose.production.yml"
require_file "deploy/nginx/mtaxi-api.conf"
require_executable "deploy/vps_prereq_check.sh"
require_executable "deploy/install_vps_units.sh"
require_executable "deploy/ops_check.sh"
require_file "scripts/remote_backend_url_guard.sh"
require_executable "scripts/check_release_ready.sh"
require_executable "scripts/build_backend_release.sh"
require_executable "scripts/check_vps_postdeploy.sh"
require_executable "scripts/check_backend_transfer_steps.sh"
require_executable "scripts/check_local_flutter_commands.sh"
require_executable "scripts/check_backend_env_contract.sh"
require_file "deploy/systemd/mtaxi-backend.service"
require_file "deploy/systemd/mtaxi-backup.service"
require_file "deploy/systemd/mtaxi-backup.timer"
require_file "deploy/systemd/mtaxi-monitor.service"
require_file "deploy/systemd/mtaxi-monitor.timer"
require_file "server/db/schema.sql"
require_file "server/scripts/backup_backend.js"
require_file "server/scripts/restore_backend.js"
require_file "server/scripts/export_env_contract.js"

case "$(grep -E '^NODE_ENV=' server/.env 2>/dev/null | tail -1 | cut -d= -f2- || true)" in
  ""|"production") ;;
  *) fail "server/.env must not set NODE_ENV to non-production value" ;;
esac

./deploy/vps_prereq_check.sh
./scripts/check_backend_transfer_steps.sh
./scripts/check_local_flutter_commands.sh

(cd server && npm ci --omit=dev)
./scripts/check_backend_env_contract.sh
(cd server && npm run validate:production-deploy)

if command -v docker >/dev/null 2>&1; then
  docker compose -f docker-compose.production.yml config >/dev/null
else
  echo "WARN docker not found; skipped docker compose config" >&2
fi

if command -v nginx >/dev/null 2>&1; then
  nginx -t -c "$root_dir/deploy/nginx/mtaxi-api.conf" >/dev/null || \
    echo "WARN nginx standalone syntax check may fail until SSL paths and includes are installed on VPS" >&2
else
  echo "WARN nginx not found; skipped nginx syntax check" >&2
fi

echo "MTaxi predeploy check passed"
