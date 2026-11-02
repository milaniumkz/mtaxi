#!/usr/bin/env bash
set -euo pipefail
revision="${1:?Pinned revision required}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
exec 9>/run/lock/mtaxi-deploy.lock
flock -w 300 9
cd /opt/mtaxi
test -f .git-deploy-managed
test -z "$(git status --porcelain --untracked-files=no)"
previous=$(git rev-parse HEAD)
git fetch origin codex/full-audit-20261023
git merge-base --is-ancestor "$previous" "$revision"
# This workflow must never silently change backend, database or deployment configuration.
test -z "$(git diff --name-only "$previous" "$revision" -- server docker-compose.production.yml deploy/vps.compose.yml)"
backup="/var/backups/mtaxi/web-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$backup"
tar --exclude='./downloads' -czf "$backup/web.tar.gz" -C /var/www/mtaxi .
printf '%s\n' "$previous" > "$backup/previous-revision"
rollback() {
  git checkout --detach "$previous"
  tar -xzf "$backup/web.tar.gz" -C /var/www/mtaxi
}
trap rollback ERR
git checkout --detach "$revision"
find /var/www/mtaxi -mindepth 1 -maxdepth 1 ! -name downloads -exec rm -rf -- {} +
tar -xzf /opt/mtaxi-incoming/web.tar.gz -C /var/www/mtaxi
find /var/www/mtaxi -path /var/www/mtaxi/downloads -prune -o -type d -exec chmod 755 {} +
find /var/www/mtaxi -path /var/www/mtaxi/downloads -prune -o -type f -exec chmod 644 {} +
curl --fail --silent --show-error https://mtaxi.89.126.192.185.sslip.io/readyz
curl --fail --silent --show-error --output /dev/null https://mtaxi.89.126.192.185.sslip.io/
printf 'Web revision: %s; backup: %s; APK and backend unchanged\n' "$revision" "$backup"
trap - ERR
