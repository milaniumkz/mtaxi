#!/usr/bin/env bash
# Executed on an inspected Debian/Ubuntu VPS by GitHub Actions.
set -euo pipefail
incoming=/opt/mtaxi-incoming
root=/opt/mtaxi
for cmd in docker nginx certbot curl tar; do
  command -v "$cmd" >/dev/null || { echo "Install prerequisite on VPS: $cmd" >&2; exit 1; }
done
docker compose version >/dev/null
# Do not overwrite an unrelated pre-existing directory or nginx site.
if [ -d "$root" ] && [ ! -f "$root/.git-deploy-managed" ]; then
  echo 'Existing /opt/mtaxi requires inspection before adoption'; exit 1
fi
site=/etc/nginx/sites-available/mtaxi-git
if [ -e "$site" ] && ! grep -q 'Managed by MTaxi Git deploy' "$site"; then
  echo 'Existing nginx site requires inspection'; exit 1
fi
install -d -m 755 "$root" /var/www/mtaxi /var/www/mtaxi-acme /var/backups/mtaxi
umask 077
tar -xzf "$incoming/source.tar.gz" -C "$root"
touch "$root/.git-deploy-managed"
install -m 600 "$incoming/production.env" "$root/server/.env"
cd "$root"
# A startup seed resets admin passwords; provision first admin separately and disable it afterwards.
if grep -Eq '^MTAXI_SEED_ADMIN_ON_START=true' server/.env; then
  echo 'Seed admin once separately; set MTAXI_SEED_ADMIN_ON_START=false before automatic deploy'; exit 1
fi
docker compose -p mtaxi -f docker-compose.production.yml up -d --build --wait --wait-timeout 180
curl --fail --silent http://127.0.0.1:8080/readyz
if [ ! -e /etc/letsencrypt/live/mtaxi.app.kz/fullchain.pem ]; then
  cat > "$site" <<'NGINX'
# Managed by MTaxi Git deploy
server {
 listen 80;
 server_name mtaxi.app.kz;
 location /.well-known/acme-challenge/ { root /var/www/mtaxi-acme; }
 location / { return 503; }
}
NGINX
  ln -sfn "$site" /etc/nginx/sites-enabled/mtaxi-git
  nginx -t
  systemctl reload nginx
  certbot certonly --webroot -w /var/www/mtaxi-acme -d mtaxi.app.kz --non-interactive --agree-tos --register-unsafely-without-email
fi
install -m 644 deploy/nginx/mtaxi-web.conf "$site"
ln -sfn "$site" /etc/nginx/sites-enabled/mtaxi-git
nginx -t
tar -xzf "$incoming/web.tar.gz" -C /var/www/mtaxi
find /var/www/mtaxi -type d -exec chmod 755 {} +
find /var/www/mtaxi -type f -exec chmod 644 {} +
systemctl reload nginx
systemctl enable --now certbot.timer
curl --fail --silent https://mtaxi.app.kz/readyz
curl --fail --silent --output /dev/null https://mtaxi.app.kz/admin
rm -f "$incoming/production.env"
