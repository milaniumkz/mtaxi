#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
handoff_dir_input="${1:-$root_dir/output/mtaxi-vps-handoff-$stamp}"
case "$handoff_dir_input" in
  /*) handoff_dir="$handoff_dir_input" ;;
  *) handoff_dir="$root_dir/$handoff_dir_input" ;;
esac

fail() {
  echo "MTaxi VPS handoff package failed: $*" >&2
  exit 1
}

mkdir -p "$handoff_dir"
if [ -n "$(find "$handoff_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  fail "handoff directory must be empty: $handoff_dir"
fi

if [ "${MTAXI_VPS_HANDOFF_SKIP_READY:-false}" = "true" ]; then
  echo "MTaxi VPS handoff: readiness gate skipped by MTAXI_VPS_HANDOFF_SKIP_READY=true"
else
  "$root_dir/scripts/check_backend_migration_ready.sh"
fi

archive_path="$handoff_dir/mtaxi-source-$stamp.tar.gz"
MTAXI_SOURCE_ARCHIVE_DIR="$handoff_dir" "$root_dir/scripts/package_source_archive.sh" "$archive_path"
archive_name="$(basename "$archive_path")"
archive_sha="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
archive_size_bytes="$(wc -c <"$archive_path" | tr -d ' ')"
cp "$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir/verify_vps_handoff.sh"
chmod +x "$handoff_dir/verify_vps_handoff.sh"
"$root_dir/scripts/backend_migration_status.sh" "$handoff_dir/READINESS_REPORT.json"
(cd "$root_dir/server" && npm run contract:api -- "$handoff_dir/API_CONTRACT.json" >/dev/null)
(cd "$root_dir/server" && npm run contract:env -- "$handoff_dir/ENV_CONTRACT.json" >/dev/null)

cat >"$handoff_dir/HANDOFF_QUICK_COMMANDS.md" <<'EOF'
# MTaxi quick VPS commands

Fill these values locally before upload:

```bash
export MTAXI_VPS_USER=root
export MTAXI_VPS_HOST=YOUR_VPS_IP_OR_DOMAIN
export MTAXI_API_URL=https://api.mtaxi.kz
```

Upload the latest verified handoff:

```bash
LATEST_HANDOFF="$(./scripts/latest_vps_handoff.sh | awk -F': ' '/Latest verified MTaxi VPS handoff/ {print $2}')"
ssh "$MTAXI_VPS_USER@$MTAXI_VPS_HOST" 'rm -rf /tmp/mtaxi-handoff && mkdir -p /tmp/mtaxi-handoff'
scp "$LATEST_HANDOFF"/* "$MTAXI_VPS_USER@$MTAXI_VPS_HOST:/tmp/mtaxi-handoff/"
```

Run on the VPS:

```bash
cd /tmp/mtaxi-handoff
chmod +x verify_vps_handoff.sh
shasum -a 256 -c mtaxi-source-*.tar.gz.sha256
./verify_vps_handoff.sh .
sudo rm -rf /opt/mtaxi
sudo mkdir -p /opt/mtaxi
sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi
cd /opt/mtaxi
./deploy/vps_prereq_check.sh
cp docs/vps_inputs.template.env /tmp/mtaxi-vps-inputs.env
# edit /tmp/mtaxi-vps-inputs.env with real values
./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env
set -a
. /tmp/mtaxi-vps-inputs.env
set +a
./scripts/generate_production_env.sh server/.env
./deploy/predeploy_check.sh
sudo ./deploy/install_vps_units.sh
sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer
./scripts/check_vps_postdeploy.sh
MTAXI_BACKEND_URL="$MTAXI_API_URL" ./scripts/build_backend_release.sh web|apk|ios
```

Firebase is allowed only for FCM push.
EOF

cat >"$handoff_dir/DEPLOY_NEXT_STEPS.md" <<'EOF'
# MTaxi VPS handoff

1. Upload `mtaxi-source-*.tar.gz`, `mtaxi-source-*.tar.gz.sha256`,
   `HANDOFF_MANIFEST.json`, `HANDOFF_STATUS.md`, `HANDOFF_QUICK_COMMANDS.md`,
   `READINESS_REPORT.json`, `API_CONTRACT.json`, `ENV_CONTRACT.json` and `verify_vps_handoff.sh`
   to `/tmp/mtaxi-handoff` on the VPS. For copy-paste commands open
   `HANDOFF_QUICK_COMMANDS.md`.
2. Verify handoff before extraction:
   ```bash
   cd /tmp/mtaxi-handoff
   chmod +x verify_vps_handoff.sh
   shasum -a 256 -c mtaxi-source-*.tar.gz.sha256
   ./verify_vps_handoff.sh .
   ```
3. Extract source archive to `/opt/mtaxi` and enter project:
   ```bash
   sudo mkdir -p /opt/mtaxi
   sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi
   cd /opt/mtaxi
   ```
   Main small-step plan: `docs/backend_migration_small_steps.md`.
   Server transfer steps: `docs/backend_transfer_steps.md`.
   Verify local transfer helpers:
   ```bash
   ./scripts/check_backend_migration_small_steps.sh
   ./scripts/check_backend_api_contract.sh
   ./scripts/check_backend_env_contract.sh
   ./scripts/check_backend_transfer_steps.sh
   ./scripts/check_local_backend_runbook.sh
   ./scripts/check_local_functional_smoke.sh
   ./scripts/check_vps_cutover_runbook.sh
   ./scripts/check_local_flutter_commands.sh
   ./scripts/check_output_handoffs.sh output
   ```
4. Check VPS prerequisites:
   `./deploy/vps_prereq_check.sh`
5. Fill and verify VPS inputs:
   ```bash
   cp docs/vps_inputs.template.env /tmp/mtaxi-vps-inputs.env
   # edit /tmp/mtaxi-vps-inputs.env with real VPS, DNS, SMS, payment, FCM and admin values
   ./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env
   ```
6. Create production env. Either copy `server/.env.example` to `server/.env`
   manually, or use `./scripts/generate_production_env.sh server/.env` with
   real `MTAXI_PUBLIC_BASE_URL`, `MTAXI_SMS_HTTP_URL`,
   `MTAXI_PAYMENT_URL_TEMPLATE` and FCM credentials.
   To use the checked VPS inputs:
   ```bash
   set -a
   . /tmp/mtaxi-vps-inputs.env
   set +a
   ./scripts/generate_production_env.sh server/.env
   ```
7. Run:
   `./deploy/predeploy_check.sh`
8. Install units:
   `sudo ./deploy/install_vps_units.sh`
9. Start services:
   `sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer`
10. Run postdeploy gate:
   `./scripts/check_vps_postdeploy.sh`
   It reads `MTAXI_PUBLIC_BASE_URL` from `server/.env`. To override:
   `MTAXI_POSTDEPLOY_BASE_URL=https://api.mtaxi.kz ./scripts/check_vps_postdeploy.sh`
11. Quick ops diagnostics if needed:
   `MTAXI_OPS_BASE_URL=https://api.mtaxi.kz ./deploy/ops_check.sh`
12. Build app releases only after smoke passes:
   `MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web|apk|ios`

Firebase is allowed only for FCM push. Do not add Firebase Auth, Firestore,
Cloud Functions, Storage or SMS back into production.
EOF

cat >"$handoff_dir/HANDOFF_STATUS.md" <<EOF
# MTaxi backend handoff status

Status: ready for VPS cutover, pending real server inputs.
Readiness: 99% locally ready; final 1% requires real VPS/domain/env and production smoke.

Checked locally before packaging:

- Backend tests
- Shell syntax
- JavaScript syntax
- Firebase FCM-only guard
- Client backend-only static check
- Client backend config check
- Backend API contract verification
- Backend env contract verification
- Local backend contract check
- Local Flutter command helper
- Local backend runbook verification
- Local functional smoke
- Local JSON backend smoke without Docker
- Source archive verification
- Backend migration status report verification
- Backend migration small steps verification
- Backend transfer steps verification
- VPS cutover runbook verification
- Latest VPS handoff helper verification
- Output handoff inventory verification
- VPS upload command helper verification
- VPS handoff extract smoke verification
- VPS cutover dry-run verification
- Step-by-step transfer document
- Backup manifest verification script
- VPS postdeploy check script
- VPS handoff manifest/checksum verification

Still required for 100%:

- VPS SSH access
- API domain and DNS
- Production \`server/.env\`
- Real SMS provider
- Real payment provider
- FCM service account for push only
- Production smoke/monitor after deployment

Firebase must stay limited to FCM push. Do not use Firebase Auth, Firestore,
Cloud Functions, Storage or SMS for production backend data.
EOF

cat >"$handoff_dir/HANDOFF_MANIFEST.json" <<EOF
{
  "type": "mtaxi-vps-handoff",
  "version": 1,
  "createdAt": "$stamp",
  "sourceArchive": "$archive_name",
  "sourceArchiveSha256": "$archive_sha",
  "sourceArchiveSizeBytes": $archive_size_bytes,
  "nextSteps": "DEPLOY_NEXT_STEPS.md",
  "quickCommands": "HANDOFF_QUICK_COMMANDS.md",
  "status": "HANDOFF_STATUS.md",
  "readinessReport": "READINESS_REPORT.json",
  "apiContract": "API_CONTRACT.json",
  "envContract": "ENV_CONTRACT.json",
  "verifier": "verify_vps_handoff.sh",
  "firebaseUsage": "FCM push only",
  "readinessPercent": 99,
  "readinessRemaining": "real VPS/domain/env and production smoke",
  "verifiedChecks": [
    "backend tests",
    "shell syntax",
    "JavaScript syntax",
    "Firebase FCM-only guard",
    "client backend-only static check",
    "client backend config check",
    "backend API contract verification",
    "backend env contract verification",
    "local backend contract check",
    "local Flutter command helper",
    "local backend runbook verification",
    "local functional smoke",
    "local JSON backend smoke",
    "source archive verification",
    "backend migration status report verification",
    "backend migration small steps verification",
    "backend transfer steps verification",
    "VPS cutover runbook verification",
    "latest VPS handoff helper verification",
    "output handoff inventory verification",
    "VPS upload command helper verification",
    "VPS handoff extract smoke verification",
    "VPS cutover dry-run verification",
    "backup manifest verification script",
    "VPS postdeploy check script",
    "VPS handoff manifest/checksum verification"
  ]
}
EOF

"$root_dir/scripts/verify_source_archive.sh" "$archive_path"
"$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir"
"$handoff_dir/verify_vps_handoff.sh" "$handoff_dir"

[ -f "$archive_path.sha256" ] || fail "missing checksum: $archive_path.sha256"
[ -f "$handoff_dir/DEPLOY_NEXT_STEPS.md" ] || fail "missing DEPLOY_NEXT_STEPS.md"
[ -f "$handoff_dir/HANDOFF_QUICK_COMMANDS.md" ] || fail "missing HANDOFF_QUICK_COMMANDS.md"
[ -f "$handoff_dir/HANDOFF_STATUS.md" ] || fail "missing HANDOFF_STATUS.md"
[ -f "$handoff_dir/HANDOFF_MANIFEST.json" ] || fail "missing HANDOFF_MANIFEST.json"
[ -f "$handoff_dir/API_CONTRACT.json" ] || fail "missing API_CONTRACT.json"
[ -f "$handoff_dir/ENV_CONTRACT.json" ] || fail "missing ENV_CONTRACT.json"
[ -x "$handoff_dir/verify_vps_handoff.sh" ] || fail "missing executable verify_vps_handoff.sh"

handoff_parent="$(dirname "$handoff_dir")"
if [ "$(basename "$handoff_parent")" = "output" ]; then
  archive_file_name="$(basename "$archive_path")"
  cat >"$handoff_parent/LATEST_MTAXI_VPS_HANDOFF.txt" <<EOF
Latest verified MTaxi VPS handoff: $handoff_dir
Source archive: $archive_file_name
EOF
fi

echo "MTaxi VPS handoff package ready: $handoff_dir"
