#!/usr/bin/env bash
set -euo pipefail
host=mtaxi-controls.89.126.192.185.sslip.io
exec 9>/run/lock/mtaxi-deploy.lock
flock -w 300 9
cd /opt/mtaxi
test -f .git-deploy-managed
test -f /var/www/mtaxi/main.dart.js
backup="/var/backups/mtaxi/admin-domain-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$backup"
install -d -m 755 /var/www/mtaxi-acme /var/www/mtaxi-acme/.well-known /var/www/mtaxi-acme/.well-known/acme-challenge
install -m 600 server/.env "$backup/server.env"
site=/etc/nginx/sites-available/mtaxi-controls
if test -f "$site"; then install -m 600 "$site" "$backup/nginx.conf"; fi
cat > "$site" <<NGINX
server {
 listen 80;
 server_name $host;
 location /.well-known/acme-challenge/ { root /var/www/mtaxi-acme; }
 location / { return 301 https://\$host\$request_uri; }
}
NGINX
ln -sfn "$site" /etc/nginx/sites-enabled/mtaxi-controls
nginx -t
systemctl reload nginx
printf 'mtaxi-admin-acme-ready' > /var/www/mtaxi-acme/.well-known/acme-challenge/mtaxi-permission-check
chmod 644 /var/www/mtaxi-acme/.well-known/acme-challenge/mtaxi-permission-check
curl --fail --silent --show-error -H "Host: $host" http://127.0.0.1/.well-known/acme-challenge/mtaxi-permission-check
rm /var/www/mtaxi-acme/.well-known/acme-challenge/mtaxi-permission-check
certbot certonly --webroot -w /var/www/mtaxi-acme --non-interactive --agree-tos --register-unsafely-without-email --cert-name "$host" -d "$host" --keep-until-expiring
cat >> "$site" <<NGINX
server {
 listen 443 ssl;
 server_name $host;
 ssl_certificate /etc/letsencrypt/live/$host/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/$host/privkey.pem;
 ssl_protocols TLSv1.2 TLSv1.3;
 root /var/www/mtaxi;
 index index.html;
 client_max_body_size 25m;
 add_header X-Content-Type-Options nosniff always;
 add_header Referrer-Policy strict-origin-when-cross-origin always;
 add_header X-Robots-Tag "noindex, nofollow" always;
 location ~ ^/(call/|create-token\$|readyz\$|livez\$|health\$|uploads/|payments/) {
  proxy_pass http://127.0.0.1:8080;
  proxy_set_header Host \$host;
  proxy_set_header X-Forwarded-For \$remote_addr;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_read_timeout 60s;
 }
 location /downloads/ { return 404; }
 location ~ /(index.html|flutter_bootstrap.js|flutter_service_worker.js|firebase-messaging-sw.js)\$ {
  add_header Cache-Control 'no-cache';
  try_files \$uri =404;
 }
 location / { try_files \$uri \$uri/ /index.html; }
}
NGINX
nginx -t
compose=(docker compose -p mtaxi -f docker-compose.production.yml -f deploy/vps.compose.yml)
rollback() {
  install -m 600 "$backup/server.env" server/.env
  "${compose[@]}" up -d --no-build --force-recreate --wait --wait-timeout 240 backend
  if test -f "$backup/nginx.conf"; then install -m 644 "$backup/nginx.conf" "$site"; else rm -f /etc/nginx/sites-enabled/mtaxi-controls "$site"; fi
  nginx -t && systemctl reload nginx
}
trap rollback ERR
python3 - <<'PY'
from pathlib import Path
p=Path('server/.env')
lines=p.read_text().splitlines()
key='MTAXI_CORS_ORIGINS'
origin='https://mtaxi-controls.89.126.192.185.sslip.io'
found=False
for i,line in enumerate(lines):
 if line.startswith(key+'='):
  found=True
  value=line.split('=',1)[1].strip().strip('"').strip("'")
  origins=[x.strip() for x in value.split(',') if x.strip()]
  if not origins: raise SystemExit('Refusing to replace an unrestricted CORS configuration without review')
  if origin not in origins: origins.append(origin)
  lines[i]=key+'='+','.join(origins)
if not found: raise SystemExit('Missing explicit CORS allowlist')
p.write_text('\n'.join(lines)+'\n')
p.chmod(0o600)
PY
# Reuse the existing backend image. No APK, web compilation, seeding or financial changes.
"${compose[@]}" up -d --no-build --force-recreate --wait --wait-timeout 240 backend
systemctl reload nginx
curl --fail --silent --show-error "https://$host/readyz"
curl --fail --silent --show-error --output /dev/null "https://$host/"
printf 'Admin domain ready: https://%s/; configuration backup: %s\n' "$host" "$backup"
trap - ERR
