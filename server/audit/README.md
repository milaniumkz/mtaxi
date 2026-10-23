# Isolated MTaxi audit tools

These tools use synthetic users and local PostgreSQL databases whose names contain `audit`. `seed.js` clears the test database collections. Create a new database for each run. No production connection belongs in this environment.

The backend launcher replaces geocoding/routing with test adapters and refuses other fetch calls. SMS and FCM are disabled; manual Kaspi operations update only test records. The load model seeds exactly600 passengers,390 drivers and10 administrators, with distinct signed sessions. It does not register FCM tokens or measure push fanout/delivery. Password login is covered separately by the backend tests.

A local example, from the repository root (Docker and server dependencies must already be available):

```bash
umask 077
audit_dir="$(mktemp -d)"
mkdir -p output/repro-load

docker run -d --name mtaxi-audit-repro-pg --cpus=2 --memory=1g \
  -e POSTGRES_HOST_AUTH_METHOD=trust -p 127.0.0.1:15432:5432 postgres:16-alpine
# Wait until this specific container is ready before the next command.
docker exec mtaxi-audit-repro-pg createdb -U postgres mtaxi_audit_repro

export MTAXI_STORE=postgres
export DATABASE_URL=postgres://postgres@127.0.0.1:15432/mtaxi_audit_repro
export MTAXI_TOKEN_SECRET="$(openssl rand -hex 32)"
export MTAXI_FCM_ENABLED=false
export MTAXI_SMS_AUTH_ENABLED=false
export MTAXI_SMS_PROVIDER=disabled
export MTAXI_PAYMENT_MODE=kaspi_manual
export MTAXI_MAINTENANCE_INTERVAL_SEC=0
export MTAXI_DATA_DIR="$audit_dir/data"
export MTAXI_UPLOAD_DIR="$audit_dir/uploads"
export MTAXI_AUDIT_ACTORS="$audit_dir/actors.json"
export MTAXI_AUDIT_METRICS="$PWD/output/repro-load/backend.jsonl"
export MTAXI_AUDIT_RESULT="$PWD/output/repro-load/result.json"
export MTAXI_AUDIT_BASE=http://127.0.0.1:18087
export MTAXI_AUDIT_REVISION="$(git rev-parse HEAD)"
export MTAXI_PUBLIC_BASE_URL=http://127.0.0.1:18087
export PORT=18087

node server/scripts/apply_schema.js
node server/audit/seed.js
node server/audit/launch.js > output/repro-load/backend.log 2>&1 &
audit_backend_pid=$!
# Check local readiness before starting the generator.
curl --fail http://127.0.0.1:18087/readyz
node server/audit/load.js > output/repro-load/load.log 2>&1
export MTAXI_AUDIT_RECONCILIATION="$PWD/output/repro-load/reconciliation.json"
node server/audit/reconcile.js
kill "$audit_backend_pid"
wait "$audit_backend_pid"
```

Use a different loopback port if15432 is already occupied; adjust DATABASE_URL accordingly. `load.js` accepts only its explicit local audit HTTP ports. The plan takes approximately37 minutes if all phases complete. It stops at >5% unexpected errors over a sliding minute or a monitored DB-integrity failure; keep the failed result files. The final reconciliation checks each user's cash, driver-bonus and passenger-bonus balances against postings, including reservations/repricing and daily rewards.

`load.js --diagnostic` runs only50 sessions/60seconds of session polling. It cannot prove full trip capacity. The full model uses a2-second state poll, at least3seconds between GPS submissions, and synthetic trip dwell times. Automatic arrival may advance the assigned phase before its nominal30-second dwell.

Use another isolated database for `api_checks.js` and browser work, preserving the load fixture's starting balances. `MTAXI_AUDIT_API_BASE` accepts local18084/18086. `MTAXI_AUDIT_BROWSER_OUTPUT` separates screenshot/matrix directories. The interactive browser controller uses local Chromium/Playwright paths supplied by this cloud environment; they need adapting elsewhere. Run `browser_tour.cjs` and `browser_journey.cjs` from that controller. Font GETs are allowed; maps are synthetic. Browser flows do not replace Android/iOS device testing.

The reports and artifact aggregators for2026-10-23 refer explicitly to `output/load-followup/` so earlier failed and final runs stay distinguishable. See `docs/load_followup_2026-10-23.md` for actual versions, resource limits and results.
