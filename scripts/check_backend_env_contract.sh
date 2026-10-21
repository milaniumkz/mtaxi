#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

fail() {
  echo "MTaxi backend env contract check failed: $*" >&2
  exit 1
}

(
  cd "$root_dir/server"
  npm run contract:env -- "$tmp_file" >/dev/null
)

node - "$tmp_file" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const contract = JSON.parse(fs.readFileSync(file, "utf8"));
function fail(message) {
  console.error(message);
  process.exit(1);
}
if (contract.type !== "mtaxi-backend-env-contract") fail("wrong contract type");
if (contract.firebaseUsage !== "FCM push only") fail("Firebase must stay FCM push only");
if (contract.store !== "PostgreSQL in production") fail("production store must be PostgreSQL");
for (const [name, value] of Object.entries({
  NODE_ENV: "production",
  MTAXI_STORE: "postgres",
  MTAXI_SMS_PROVIDER: "disabled",
  MTAXI_PAYMENT_PROVIDER: "redirect",
  MTAXI_FCM_ENABLED: "true",
})) {
  if (contract.productionValues?.[name] !== value) fail(`wrong production value for ${name}`);
}
for (const name of [
  "MTAXI_PUBLIC_BASE_URL",
  "MTAXI_TOKEN_SECRET",
  "DATABASE_URL",
  "MTAXI_PAYMENT_URL_TEMPLATE",
  "MTAXI_PAYMENT_CALLBACK_SECRET",
]) {
  if (!contract.requiredProduction?.includes(name)) fail(`missing required env: ${name}`);
}
for (const name of [
  "MTAXI_ALLOW_LOCAL_SMS",
  "MTAXI_ALLOW_LOCAL_PAYMENT",
  "MTAXI_ALLOW_SIMULATED_PUSH",
  "MTAXI_ENABLE_LEGACY_CREATE_TOKEN",
]) {
  if (!contract.forbiddenTrueInProduction?.includes(name)) fail(`missing forbidden dev flag: ${name}`);
}
if (!contract.firebaseCredentialRequirement?.includes("FIREBASE_SERVICE_ACCOUNT_JSON")) {
  fail("missing FCM credential requirement");
}
if (!Array.isArray(contract.missingInExample) || contract.missingInExample.length !== 0) {
  fail("env example is missing production keys");
}
if (!Array.isArray(contract.mismatchedProductionDefaults) || contract.mismatchedProductionDefaults.length !== 0) {
  fail("env example production defaults drifted");
}
if (!Array.isArray(contract.unsafeDevDefaults) || contract.unsafeDevDefaults.length !== 0) {
  fail("env example enables unsafe dev flags");
}
NODE

echo "MTaxi backend env contract check passed: $tmp_file"
