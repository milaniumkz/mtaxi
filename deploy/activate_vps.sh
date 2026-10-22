#!/usr/bin/env bash
set -euo pipefail
# An interrupted SSH client must not overlap another backend activation.
exec 9>/run/lock/mtaxi-deploy.lock
flock -w 300 9
cd /opt/mtaxi
test -f .git-deploy-managed
test -f /etc/mtaxi/firebase.json
git fetch origin codex/free-staging-20261021
git merge --ff-only origin/codex/free-staging-20261021
compose=(docker compose -p mtaxi -f docker-compose.production.yml -f deploy/vps.compose.yml)
"${compose[@]}" up -d --build --wait --wait-timeout 240
"${compose[@]}" exec -T backend node <<'JS'
(async()=>{
 const {readStoreAsync}=require('./src/store');
 const {seedAdmin}=require('./scripts/seed_admin');
 const {normalizePhone}=require('./src/utils/values');
 const store=await readStoreAsync();
 if(!store.users.some(u=>u.role==='admin')){
  if(store.users.some(u=>normalizePhone(u.phone)===normalizePhone(process.env.MTAXI_ADMIN_PHONE)))throw new Error('Administrator phone already used');
  const result=await seedAdmin();if(!result.success)throw new Error('Administrator bootstrap failed');
  console.log('Initial administrator created');
 } else console.log('Existing administrator preserved');
 process.exit(0);
})().catch(()=>{console.error('Administrator bootstrap failed');process.exit(1)});
JS
"${compose[@]}" exec -T backend node scripts/check_firebase_fcm.js </dev/null
curl --fail --silent http://127.0.0.1:8080/readyz
host=mtaxi.89.126.192.185.sslip.io
sed "s/mtaxi.app.kz/$host/g" deploy/nginx/mtaxi-web.conf > /etc/nginx/sites-available/mtaxi-test
nginx -t
systemctl reload nginx
systemctl disable --now mtaxi-bootstrap.service || true
rm -f /etc/mtaxi/bootstrap-token
curl --fail --silent "https://$host/readyz"
# Backups persist on the VPS; off-server backup is still required before launch.
cat > /etc/systemd/system/mtaxi-compose-backup.service <<'UNIT'
[Unit]
Description=MTaxi PostgreSQL backup
Requires=docker.service
After=docker.service
[Service]
Type=oneshot
WorkingDirectory=/opt/mtaxi
ExecStart=/usr/bin/docker compose -p mtaxi -f docker-compose.production.yml -f deploy/vps.compose.yml exec -T backend npm run db:backup
UNIT
cat > /etc/systemd/system/mtaxi-compose-backup.timer <<'UNIT'
[Unit]
Description=Daily MTaxi backup
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now mtaxi-compose-backup.timer
install -d -m 700 /var/backups/mtaxi
"${compose[@]}" exec -T backend npm run db:backup </dev/null
