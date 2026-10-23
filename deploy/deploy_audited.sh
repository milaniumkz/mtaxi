#!/usr/bin/env bash
set -euo pipefail
revision="${1:?Pinned Git revision required}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
exec 9>/run/lock/mtaxi-deploy.lock
flock -w 300 9
cd /opt/mtaxi
test -f .git-deploy-managed
test -z "$(git status --porcelain --untracked-files=no)"
compose=(docker compose -p mtaxi -f docker-compose.production.yml -f deploy/vps.compose.yml)
previous=$(git rev-parse HEAD)
container=$("${compose[@]}" ps -q backend)
test -n "$container"
old_image=$(docker inspect --format '{{.Image}}' "$container")
image_tag=$(docker inspect --format '{{.Config.Image}}' "$container")
stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="/var/backups/mtaxi/deploy-$stamp"
install -d -m 700 "$backup"
printf '%s\n' "$previous" > "$backup/previous-revision"
printf '%s\n' "$old_image" > "$backup/previous-image"
tar -czf "$backup/web.tar.gz" -C /var/www/mtaxi .
chmod 600 "$backup/web.tar.gz"
"${compose[@]}" exec -T backend npm run db:backup </dev/null
git fetch origin codex/full-audit-20261023
git cat-file -e "$revision^{commit}"
git merge-base --is-ancestor "$previous" "$revision"
git checkout --detach "$revision"
rollback() {
  echo 'Deployment failed; restoring previous backend and web artifacts.' >&2
  git checkout --detach "$previous"
  docker tag "$old_image" "$image_tag"
  "${compose[@]}" up -d --no-build --wait --wait-timeout 240 backend
  tar -xzf "$backup/web.tar.gz" -C /var/www/mtaxi
}
trap rollback ERR
"${compose[@]}" build backend
# Stop old workers before the final snapshot and schema/ownership migration.
"${compose[@]}" stop backend
"${compose[@]}" run --rm --no-deps backend npm run db:backup </dev/null
"${compose[@]}" run --rm --no-deps backend node scripts/apply_schema.js </dev/null
"${compose[@]}" run --rm --no-deps backend node scripts/reconcile_upload_owners.js </dev/null
"${compose[@]}" up -d --no-build --wait --wait-timeout 240 backend
curl --fail --silent http://127.0.0.1:8080/readyz
# Keep downloads while replacing all web assets, including obsolete generated chunks.
find /var/www/mtaxi -mindepth 1 -maxdepth 1 ! -name downloads -exec rm -rf -- {} +
tar -xzf /opt/mtaxi-incoming/web.tar.gz -C /var/www/mtaxi
find /var/www/mtaxi -type d -exec chmod 755 {} +
find /var/www/mtaxi -type f -exec chmod 644 {} +
bash deploy/publish_test_apk.sh /opt/mtaxi-incoming /var/www/mtaxi/downloads
curl --fail --silent https://mtaxi.89.126.192.185.sslip.io/readyz
printf 'Deployed revision: %s; previous revision: %s; backup: %s\n' "$revision" "$previous" "$backup"
trap - ERR
