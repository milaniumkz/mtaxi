#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
host=mtaxi.89.126.192.185.sslip.io
root=/opt/mtaxi
if [ -e "$root" ] && [ ! -e "$root/.git-deploy-managed" ]; then echo 'Unmanaged application directory; stop'; exit 1; fi
apt-get update -qq
apt-get install -y docker.io docker-compose-v2 nginx certbot python3 openssl curl
systemctl enable --now docker nginx
install -d -m 700 /etc/mtaxi
install -d -m 755 "$root" /var/www/mtaxi /var/www/mtaxi-acme /var/backups/mtaxi
if [ ! -d "$root/.git" ]; then
 git clone --branch codex/free-staging-20261021 https://github.com/milaniumkz/mtaxi.git "$root"
else
 git -C "$root" fetch origin codex/free-staging-20261021
 git -C "$root" merge --ff-only origin/codex/free-staging-20261021
fi
touch "$root/.git-deploy-managed"
python3 - <<'PY'
import json, secrets, os
from pathlib import Path
base=Path('/etc/mtaxi')
if not (base/'bootstrap-token').exists() and not (base/'firebase.json').exists():
 (base/'bootstrap-token').write_text(secrets.token_hex(32))
if not (base/'initial-admin.json').exists():
 (base/'initial-admin.json').write_text(json.dumps({'phone':'+77009990000','password':secrets.token_hex(16)}))
admin=json.loads((base/'initial-admin.json').read_text())
p=Path('/opt/mtaxi/server/.env')
if not p.exists():
 db=secrets.token_hex(32)
 vals={'NODE_ENV':'production','PORT':'8080','MTAXI_PUBLIC_BASE_URL':'https://mtaxi.89.126.192.185.sslip.io','MTAXI_CORS_ORIGINS':'https://mtaxi.89.126.192.185.sslip.io','MTAXI_TRUST_PROXY':'1','MTAXI_STORE':'postgres','POSTGRES_PASSWORD':db,'DATABASE_URL':f'postgres://mtaxi:{db}@postgres:5432/mtaxi','MTAXI_TOKEN_SECRET':secrets.token_hex(48),'MTAXI_PAYMENT_CALLBACK_SECRET':secrets.token_hex(32),'MTAXI_PAYMENT_PROVIDER':'kaspi_manual','MTAXI_ALLOW_LOCAL_PAYMENT':'false','MTAXI_SMS_PROVIDER':'disabled','MTAXI_SMS_DEV_RETURN_CODE':'false','MTAXI_ALLOW_LOCAL_SMS':'false','MTAXI_SEED_ADMIN_ON_START':'false','MTAXI_ADMIN_PHONE':admin['phone'],'MTAXI_ADMIN_PASSWORD':admin['password'],'MTAXI_ADMIN_NAME':'Администратор','MTAXI_ADMIN_CITY':'Жетекши','MTAXI_FCM_ENABLED':'true','MTAXI_ALLOW_SIMULATED_PUSH':'false','FIREBASE_PROJECT_ID':'mtaxi-52990','GOOGLE_APPLICATION_CREDENTIALS':'/run/secrets/firebase.json','MTAXI_UPLOAD_DIR':'/var/lib/mtaxi/uploads','MTAXI_MAINTENANCE_INTERVAL_SEC':'30','MTAXI_ENABLE_LEGACY_CREATE_TOKEN':'false','MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL':'false','MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL':'false','MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY':'false'}
 p.write_text(''.join(f'{k}={v}\n' for k,v in vals.items()))
 os.chmod(p,0o600)
for p in base.iterdir():
 if p.is_file():os.chmod(p,0o600)
PY
site=/etc/nginx/sites-available/mtaxi-test
cat > "$site" <<NGINX
# Managed by MTaxi test deployment
server {
 listen 80;
 server_name $host;
 location /.well-known/acme-challenge/ { root /var/www/mtaxi-acme; }
 location / { return 503; }
}
NGINX
ln -sfn "$site" /etc/nginx/sites-enabled/mtaxi-test
nginx -t
systemctl reload nginx
if [ ! -e "/etc/letsencrypt/live/$host/fullchain.pem" ]; then
 certbot certonly --webroot -w /var/www/mtaxi-acme -d "$host" --non-interactive --agree-tos --register-unsafely-without-email
fi
sed "s/mtaxi.app.kz/$host/g" "$root/deploy/nginx/mtaxi-web.conf" > "$site"
# Keep bootstrap credentials and body out of nginx access logs.
python3 - <<'PY'
p='/etc/nginx/sites-available/mtaxi-test'
s=open(p).read().replace(' location /downloads/', ' location = /__mtaxi_initial_firebase {\n  access_log off;\n  client_max_body_size 64k;\n  proxy_pass http://127.0.0.1:8099;\n }\n location /downloads/')
open(p,'w').write(s)
PY
install -d -m 755 /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nnginx -t && systemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/mtaxi-nginx
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/mtaxi-nginx
systemctl enable --now certbot.timer
nginx -t
systemctl reload nginx
if [ ! -e /etc/mtaxi/firebase.json ]; then
 cat > /etc/systemd/system/mtaxi-bootstrap.service <<UNIT
[Unit]
Description=MTaxi one-use Firebase configuration receiver
[Service]
ExecStart=/usr/bin/python3 /opt/mtaxi/deploy/bootstrap_receiver.py
RuntimeMaxSec=1800
UMask=0077
NoNewPrivileges=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/etc/mtaxi
[Install]
WantedBy=multi-user.target
UNIT
 systemctl daemon-reload
 systemctl restart mtaxi-bootstrap.service
fi
python3 - <<'PY' | openssl pkeyutl -encrypt -pubin -inkey /opt/mtaxi/deploy/bootstrap-encrypt.pub -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 | base64 -w0
import json
from pathlib import Path
b=Path('/etc/mtaxi'); a=json.loads((b/'initial-admin.json').read_text())
t=(b/'bootstrap-token').read_text().strip() if (b/'bootstrap-token').exists() else ''
print(json.dumps({'token':t,'phone':a['phone'],'password':a['password']}))
PY
printf '\nMTAXI_BOOTSTRAP_READY\n'
