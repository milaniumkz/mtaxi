#!/usr/bin/env bash
set -euo pipefail

target_dir="${MTAXI_INSTALL_DIR:-/opt/mtaxi}"
min_disk_gb="${MTAXI_MIN_FREE_DISK_GB:-10}"

fail() {
  echo "MTaxi VPS prerequisite check failed: $*" >&2
  exit 1
}

warn() {
  echo "WARN $*" >&2
}

case "$min_disk_gb" in
  ''|*[!0-9]*) fail "MTAXI_MIN_FREE_DISK_GB must be an integer" ;;
esac

command -v docker >/dev/null 2>&1 || fail "docker is not installed"
docker compose version >/dev/null 2>&1 || fail "docker compose plugin is not available"

if command -v systemctl >/dev/null 2>&1; then
  systemctl list-unit-files >/dev/null || fail "systemd is not usable"
else
  fail "systemctl is not available"
fi

command -v curl >/dev/null 2>&1 || fail "curl is not installed"
command -v tar >/dev/null 2>&1 || fail "tar is not installed"
command -v shasum >/dev/null 2>&1 || fail "shasum is not installed"
command -v node >/dev/null 2>&1 || fail "node is not installed"
command -v npm >/dev/null 2>&1 || fail "npm is not installed"

node -e "const major = Number(process.versions.node.split('.')[0]); process.exit(major >= 20 ? 0 : 1)" \
  >/dev/null 2>&1 || fail "Node.js 20 or newer is required"

if command -v nginx >/dev/null 2>&1; then
  nginx -v >/dev/null 2>&1 || fail "nginx exists but is not runnable"
else
  warn "nginx is not installed; install nginx or another HTTPS reverse proxy before production cutover"
fi

parent_dir="$(dirname "$target_dir")"
[ -d "$parent_dir" ] || fail "install parent directory does not exist: $parent_dir"
[ -w "$parent_dir" ] || [ -w "$target_dir" ] || warn "current user cannot write $target_dir; use sudo for install/extract"

free_disk_gb="$(df -Pk "$parent_dir" | awk 'NR==2 {print int($4 / 1024 / 1024)}')"
[ "${free_disk_gb:-0}" -ge "$min_disk_gb" ] ||
  fail "not enough free disk at $parent_dir: ${free_disk_gb:-0} GiB, need ${min_disk_gb} GiB"

if command -v ss >/dev/null 2>&1; then
  if ss -ltn | awk '{print $4}' | grep -E '(:80|:443)$' >/dev/null; then
    warn "ports 80/443 already have listeners; verify reverse proxy configuration"
  fi
else
  warn "ss is not installed; skipped port listener check"
fi

echo "MTaxi VPS prerequisite check passed"
