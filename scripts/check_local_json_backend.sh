#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
default_port="${MTAXI_LOCAL_JSON_CHECK_PORT:-59630}"
base_url="${MTAXI_LOCAL_BACKEND_URL:-}"
timeout_sec="${MTAXI_LOCAL_BACKEND_TIMEOUT_SEC:-45}"
deadline=$((SECONDS + timeout_sec))
data_dir="$(mktemp -d)"
upload_dir="$(mktemp -d)"

fail() {
  echo "MTaxi local JSON backend check failed: $*" >&2
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

if [ -n "$base_url" ]; then
  base_url_port="$(printf '%s\n' "$base_url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/:]+|\[[^]]+\]):([0-9]+).*#\2#')"
  if [ "$base_url_port" = "$base_url" ]; then
    base_url_port="$default_port"
  fi
  port="${PORT:-$base_url_port}"
else
  port="${PORT:-$(node -e "const s=require('net').createServer();s.listen(0,'127.0.0.1',()=>{console.log(s.address().port);s.close();});")}"
  base_url="http://127.0.0.1:$port"
fi

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
npm run start &
backend_pid="$!"

echo "MTaxi local JSON backend check: waiting for $base_url/readyz"
until curl -fsS "$base_url/readyz" >/dev/null 2>&1; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    fail "readiness timeout after ${timeout_sec}s"
  fi
  if ! kill -0 "$backend_pid" >/dev/null 2>&1; then
    fail "backend process exited before readiness"
  fi
  sleep 1
done

"$root_dir/scripts/check_local_backend_contract.sh" "$base_url" json

echo "MTaxi local JSON backend check passed: $base_url"
