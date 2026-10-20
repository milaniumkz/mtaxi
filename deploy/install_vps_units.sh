#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="${MTAXI_INSTALL_DIR:-/opt/mtaxi}"
systemd_dir="${MTAXI_SYSTEMD_DIR:-/etc/systemd/system}"
nginx_available_dir="${MTAXI_NGINX_AVAILABLE_DIR:-/etc/nginx/sites-available}"
nginx_enabled_dir="${MTAXI_NGINX_ENABLED_DIR:-/etc/nginx/sites-enabled}"
backup_dir="${MTAXI_BACKUP_DIR:-/var/backups/mtaxi}"

fail() {
  echo "MTaxi VPS install failed: $*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing required file: $1"
}

require_file "$root_dir/deploy/systemd/mtaxi-backend.service"
require_file "$root_dir/deploy/systemd/mtaxi-backup.service"
require_file "$root_dir/deploy/systemd/mtaxi-backup.timer"
require_file "$root_dir/deploy/systemd/mtaxi-monitor.service"
require_file "$root_dir/deploy/systemd/mtaxi-monitor.timer"
require_file "$root_dir/deploy/nginx/mtaxi-api.conf"

if [ "$target_dir" != "/opt/mtaxi" ]; then
  fail "service templates use /opt/mtaxi; update deploy/systemd/*.service before installing to $target_dir"
fi

install -d -m 0750 "$backup_dir"

install -m 0644 "$root_dir/deploy/systemd/mtaxi-backend.service" "$systemd_dir/mtaxi-backend.service"
install -m 0644 "$root_dir/deploy/systemd/mtaxi-backup.service" "$systemd_dir/mtaxi-backup.service"
install -m 0644 "$root_dir/deploy/systemd/mtaxi-backup.timer" "$systemd_dir/mtaxi-backup.timer"
install -m 0644 "$root_dir/deploy/systemd/mtaxi-monitor.service" "$systemd_dir/mtaxi-monitor.service"
install -m 0644 "$root_dir/deploy/systemd/mtaxi-monitor.timer" "$systemd_dir/mtaxi-monitor.timer"

if [ -d "$nginx_available_dir" ]; then
  install -m 0644 "$root_dir/deploy/nginx/mtaxi-api.conf" "$nginx_available_dir/mtaxi-api.conf"
  if [ -d "$nginx_enabled_dir" ] && [ ! -e "$nginx_enabled_dir/mtaxi-api.conf" ]; then
    ln -s "$nginx_available_dir/mtaxi-api.conf" "$nginx_enabled_dir/mtaxi-api.conf"
  fi
else
  echo "WARN nginx sites-available not found; skipped nginx config install" >&2
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
else
  echo "WARN systemctl not found; skipped daemon-reload" >&2
fi

echo "MTaxi VPS units installed"
echo "Next:"
echo "  systemctl enable --now mtaxi-backend.service"
echo "  systemctl enable --now mtaxi-backup.timer"
echo "  systemctl enable --now mtaxi-monitor.timer"
