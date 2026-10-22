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

## Verified deployment on 2026-10-21

The public test URLs above returned HTTP 200. The backend runs Node.js 24 LTS with PostgreSQL 16; PostgreSQL client tools are pinned to major version 16 using the official signed PGDG repository and verified key fingerprint. Backup files persist under `/var/backups/mtaxi`, use private permissions and are checked by the manifest verifier. Both the backup timer and certbot timer are active; a simulated certificate renewal succeeded.

Validation: 160 backend tests and 33 Flutter tests passed, Flutter analysis was clean, and the dedicated PostgreSQL account-deletion regression test passed against PostgreSQL 16. The default backend test run skips that PostgreSQL-only test unless `MTAXI_TEST_POSTGRES_URL` names a disposable database. Do not point it at live data.

Actual public-server checks passed: admin password login and deep-link refresh in Chromium; passenger home and street autocomplete (`Абая улица, Железинка`); forward/reverse geocoding and route lookup; 500-tenge village tariffs; welcome reward exactly once; ten complete orders with bonus-first commission debits and daily reward; synthetic manual Kaspi confirmation with duplicate protection; intercity blocked; synthetic account/payment/order cleanup. Driver bonus balance and 0-of-10 progress were visually confirmed in a real browser screenshot. Flutter canvas text was not fully exposed to the initial automated DOM-text check, so that check was not counted as an automated pass. FCM Admin SDK dry run passed without recipient notifications.

Published test APK: package `com.milanium.mtaxi`, version `1.1.1` (57), minimum Android API 24, target API 35, universal profile build with test signing. Downloaded APK size: 121718633 bytes. SHA256: `e7bda4fde834b3c77105265cbec6b34f3fcc52cc353128c476c563abd9c07c15`. APK v2 signature verification passed, and all three ABI libraries contain the actual HTTPS backend URL. Installation and push receipt on a physical phone remain unverified. Store publication requires production signing; web/iOS push still require VAPID/APNs configuration.

The initial bootstrap handoff is complete. Its receiver is stopped, token removed and nginx route removed. Initial private decryption material can be deleted after the owner receives the admin access file; for a different fresh VPS, create a new key pair outside Git and replace only the public encryption key before bootstrap. Never publish the private key or admin access file.

## Verified feature deployment on 2026-10-22

Application revision `54e9eac1bda6861586999aff3ee848de41e215f8` was published by successful Actions run `39797387248`. The complete log confirms 178 backend tests passed (one PostgreSQL-only test skipped by default), 35 Flutter tests passed, clean analysis and successful web/APK builds. All 19 dedicated scenarios passed separately against disposable PostgreSQL 16, including financial reservations, concurrent fare acceptance, GPS continuity and account deletion protection.

Actual public-server checks passed: passenger Kaspi request and duplicate confirmation protection; a 500-tenge order negotiated to 700 tenge; driver road ETA; passenger acceptance in Chromium; wallet/bonus payment, driver cash credit, commission and 2% cashback; ratings; cancellation denial after start; synthetic GPS samples causing automatic arrival and departure after 15 server seconds. The public wallet UI submitted a Kaspi request and showed the confirmed 700-tenge balance. Admin login and refresh, the offer popup and the corrected road map passed Chromium checks without JavaScript exceptions. All synthetic accounts and their dependent financial/order records were removed. The served `main.dart.js` SHA256 exactly matched the locally checked web build (`ca58309c2ba0a4904af0b7eda8057616c03611f77aa5b23fdbef156a9ba4f75b`).

Published APK: `com.milanium.mtaxi`, version `1.2.0` (58), 122046745 bytes, minimum API 24 and target API 35. The downloaded public file passed APK v2 signature verification. Its SHA256 is `dd989bc220f9bfe25f8d202e3037bb7f342e195a231605848333f0100cc22598`; the deployed revision and checksum are also exposed at `/downloads/test-build.json`. The actual HTTPS backend URL was verified in all three ABI libraries. Physical installation, background GPS, spoken maneuver quality and push receipt still require phone testing.

The test signing key is retained privately on the VPS. Users of the old ephemeral-key 1.1.1 APK must uninstall that test build once before installing 1.2.0; their account data remains on the server.

The publication check caught an incomplete download while SCP was still writing the public APK. The final complete upload was downloaded again and verified as above. Subsequent publication uses `deploy/publish_test_apk.sh`: upload into the private incoming directory, verify SHA256, prepare files on the destination filesystem, replace the APK with an atomic rename and publish metadata last. The helper was checked with a corrupt-upload case that preserved the old public APK and a valid-upload case that replaced the artifacts and removed temporary files. The workflow and shell syntax checks passed. This publication-only configuration change does not require rebuilding the already verified application.
