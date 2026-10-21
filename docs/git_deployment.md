# Deployment from GitHub to the VPS

Workflow: `.github/workflows/deploy-vps.yml`, merge the reviewed branch into the default branch first, then manually start with **Actions → Deploy MTaxi VPS → Run workflow** on the branch containing this workflow. It runs backend/Flutter checks, builds web, uploads source and web over verified SSH, updates Docker Compose, obtains a Let's Encrypt certificate if missing, checks public HTTPS, builds a profile APK against that server and publishes it under `/downloads/mtaxi-staging.apk`. The APK uses test signing and is for testing, not Play Store publication.

## One-time prerequisites

1. DNS: create `mtaxi.app.kz A 89.126.192.185`. The order name alone does not create a public domain. Authoritative DNS returned NXDOMAIN on 2026-10-21. If this hostname is unavailable to you, use a domain you control and update both the workflow and nginx template before launching.
2. Inspect existing VPS services and `/opt/mtaxi` before adoption. Install Docker Engine with Compose v2, nginx, certbot, curl and tar on Debian/Ubuntu. Open inbound TCP 22, 80 and 443. Keep PostgreSQL private. The workflow intentionally does not replace an uninspected existing `/opt/mtaxi` directory or install system packages remotely.
3. In GitHub repository **Settings → Secrets and variables → Actions**, create:
   - `VPS_SSH_PASSWORD`: the supplied root password. Never commit it.
   - `VPS_KNOWN_HOSTS`: the actual SSH host public-key entry for `89.126.192.185`, verified through the hosting console. Do not trust an unverified scan blindly.
   - `MTAXI_PRODUCTION_ENV`: complete private backend env file, based on `server/.env.example`. It also supplies PostgreSQL credentials to Compose.
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: existing Firebase account JSON for native client configuration generation. Do not create or commit another private key.
4. In `MTAXI_PRODUCTION_ENV`, set production PostgreSQL mode, strong stable `POSTGRES_PASSWORD`, matching `DATABASE_URL=postgres://mtaxi:PASSWORD@postgres:5432/mtaxi`, token/callback secrets, `MTAXI_PUBLIC_BASE_URL=https://mtaxi.app.kz`, `MTAXI_CORS_ORIGINS=https://mtaxi.app.kz`, `MTAXI_TRUST_PROXY=loopback`, `MTAXI_UPLOAD_DIR=/var/lib/mtaxi/uploads`, `MTAXI_PAYMENT_PROVIDER=kaspi_manual`, `MTAXI_SMS_PROVIDER=disabled`, FCM enabled and simulated push disabled, real Firebase project/account JSON. Validate all settings with the production preflight. Do not change the PostgreSQL password blindly after the volume exists.
5. Provision the first administrator separately with the existing `seed:admin` command and a strong password. Keep `MTAXI_SEED_ADMIN_ON_START=false` for repeated deploys: automatic seeding would overwrite the administrator password. Configure and verify off-server backups using existing backup scripts before real customer data.
6. Grant this GitHub integration permission to update workflow files and dispatch/read Actions. Current integration returned HTTP 403 for Actions permissions and secrets management; it cannot populate secrets on your behalf.

On subsequent runs, existing PostgreSQL/upload volumes persist. No database volume is deleted. Failed migrations or builds stop the workflow; this is not a zero-downtime or automatically rolled-back deployment. Inspect the failed run before retrying. Certificate renewal uses `certbot.timer`; the deployment script installs an nginx reload hook after renewal (verify it using the commands below). GitHub logs and artifacts must never contain the private env file.

```sh
sudo install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nnginx -t && systemctl reload nginx\n' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/mtaxi-nginx >/dev/null
sudo chmod 755 /etc/letsencrypt/renewal-hooks/deploy/mtaxi-nginx
sudo certbot renew --dry-run
```

Expected URLs after a successful run (not yet deployed): web `https://mtaxi.app.kz/`, admin `https://mtaxi.app.kz/admin`, APK `https://mtaxi.app.kz/downloads/mtaxi-staging.apk`. Public readiness checks do not prove complete ordering, geocoding or push delivery: perform passenger/driver/admin browser and real-device checks before production. Browser push still needs VAPID configuration, and iOS push needs APNs.
