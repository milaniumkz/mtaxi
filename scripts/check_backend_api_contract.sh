#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

fail() {
  echo "MTaxi backend API contract check failed: $*" >&2
  exit 1
}

(
  cd "$root_dir/server"
  npm run contract:api -- "$tmp_file" >/dev/null
)

node - "$tmp_file" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const contract = JSON.parse(fs.readFileSync(file, "utf8"));
function fail(message) {
  console.error(message);
  process.exit(1);
}
if (contract.type !== "mtaxi-backend-api-contract") fail("wrong contract type");
if (contract.endpoint !== "POST /call/:name") fail("wrong backend endpoint");
if (contract.firebaseUsage !== "FCM push only") fail("Firebase must stay FCM push only");
if (!Array.isArray(contract.missingServerHandlers) || contract.missingServerHandlers.length !== 0) {
  fail("client has backend calls without server handlers");
}
if (!Array.isArray(contract.handlers) || contract.handlers.length < 50) fail("too few backend handlers");
for (const name of ["passwordLogin", "createPassengerOrder", "acceptOrder", "adminManageOrder", "uploadFile"]) {
  if (!contract.handlers.some((handler) => handler.name === name)) fail(`missing handler in contract: ${name}`);
}
if (!contract.handlers.some((handler) => handler.name === "requestSmsCode" && handler.rateLimited === true)) {
  fail("requestSmsCode must be rate limited");
}
NODE

echo "MTaxi backend API contract check passed: $tmp_file"
