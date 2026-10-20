#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timeout_sec="${MTAXI_LOCAL_FUNCTIONAL_SMOKE_TIMEOUT_SEC:-45}"
deadline=$((SECONDS + timeout_sec))
data_dir="$(mktemp -d)"
upload_dir="$(mktemp -d)"

fail() {
  echo "MTaxi local functional smoke failed: $*" >&2
  exit 1
}

cleanup() {
  if [ -n "${backend_pid:-}" ]; then
    kill "$backend_pid" >/dev/null 2>&1 || true
    wait "$backend_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$data_dir" "$upload_dir"
}
trap cleanup EXIT INT TERM

command -v node >/dev/null 2>&1 || fail "node is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

port="${PORT:-$(node -e "const s=require('net').createServer();s.listen(0,'127.0.0.1',()=>{console.log(s.address().port);s.close();});")}"
base_url="http://127.0.0.1:$port"

cd "$root_dir/server"

NODE_ENV=development \
PORT="$port" \
MTAXI_STORE=json \
MTAXI_DATA_DIR="$data_dir" \
MTAXI_UPLOAD_DIR="$upload_dir" \
MTAXI_PUBLIC_BASE_URL="$base_url" \
MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL=true \
MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL=true \
MTAXI_SMS_PROVIDER=local \
MTAXI_ALLOW_LOCAL_SMS=true \
MTAXI_SMS_DEV_RETURN_CODE=true \
MTAXI_PAYMENT_PROVIDER=local \
MTAXI_ALLOW_LOCAL_PAYMENT=true \
MTAXI_FCM_ENABLED=false \
MTAXI_ALLOW_SIMULATED_PUSH=true \
npm run start >/tmp/mtaxi-local-functional-smoke.log 2>&1 &
backend_pid="$!"

echo "MTaxi local functional smoke: waiting for $base_url/readyz"
until curl -fsS "$base_url/readyz" >/dev/null 2>&1; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    tail -80 /tmp/mtaxi-local-functional-smoke.log >&2 || true
    fail "readiness timeout after ${timeout_sec}s"
  fi
  if ! kill -0 "$backend_pid" >/dev/null 2>&1; then
    tail -80 /tmp/mtaxi-local-functional-smoke.log >&2 || true
    fail "backend process exited before readiness"
  fi
  sleep 1
done

MTAXI_FUNCTIONAL_SMOKE_BASE_URL="$base_url" npm run smoke:functional:local

echo "MTaxi local functional smoke passed: $base_url"
