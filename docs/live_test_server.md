# MTaxi test server

Target VPS: `89.126.192.185`, Ubuntu 24.04, Docker Compose with PostgreSQL 16 and persistent upload/database volumes. Temporary test hostname: `mtaxi.89.126.192.185.sslip.io`; `mtaxi.app.kz` still needs public DNS configuration. TLS uses Let's Encrypt with certbot renewal and nginx reload hook.

The tested GitHub-runner SSH path requires only the repository Actions secret `VPS_SSH_PASSWORD`; SSH host key is pinned in the workflows. The older `deploy-vps.yml` is a separate configurable deployment template, not the workflow used for this test server.

1. `.github/workflows/vps-access-check.yml` provisions an initially inspected, empty VPS with `deploy/bootstrap_vps.sh`. Do not rerun against an unrelated server. It generates private configuration locally on the VPS, starts a short-lived one-use HTTPS receiver and RSA-OAEP encrypts the receiver token/admin credentials to `deploy/bootstrap-encrypt.pub`. The matching private key is held outside Git in the deployment workspace. An HTTPS client transfers the existing Firebase account using that token; it is never committed or printed. The receiver deletes its token and stops after successful transfer.
2. `.github/workflows/activate-vps.yml` updates the existing managed checkout, starts PostgreSQL/backend with `deploy/vps.compose.yml`, preserves existing admin passwords, checks Firebase FCM in dry-run mode, installs daily local backups, tests/builds Flutter, publishes the web app, builds a test-signed profile APK against real HTTPS and publishes it with SHA256. The one-use receiver is disabled and its nginx route removed.

Private files: `/opt/mtaxi/server/.env`, `/etc/mtaxi/firebase.json`, `/etc/mtaxi/initial-admin.json`; mode 600. Do not print them, put them into logs or include them in source archives. Initial admin access is handed to the owner separately in a private workspace file. Use its phone as a login identifier; no SMS is sent. Change the password after first login.

Web: `https://mtaxi.89.126.192.185.sslip.io/`

Admin: `https://mtaxi.89.126.192.185.sslip.io/admin`

APK: `https://mtaxi.89.126.192.185.sslip.io/downloads/mtaxi-staging.apk`

These addresses are deployment targets; verify HTTP, browser login, geocoding and APK availability before reporting them as working. A successful FCM dry run does not establish real device receipt. Web push still needs VAPID and iOS push still needs APNs. The temporary sslip.io hostname is third-party DNS for testing; switch to the owner's configured domain for launch. Backups are on the same VPS: arrange off-server retention before production.

Run operations from `/opt/mtaxi` on the VPS:

```sh
docker compose -p mtaxi -f docker-compose.production.yml -f deploy/vps.compose.yml ps
curl -fsS https://mtaxi.89.126.192.185.sslip.io/readyz
systemctl status certbot.timer mtaxi-compose-backup.timer
docker compose -p mtaxi -f docker-compose.production.yml -f deploy/vps.compose.yml exec -T backend npm run db:backup
```

Do not delete Compose volumes to troubleshoot startup. Do not rerun `seed:admin` against an existing admin: it changes that user's password. Backend startup sets launch defaults once and preserves subsequent admin edits.
