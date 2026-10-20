#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_url="${MTAXI_LOCAL_BACKEND_URL:-http://127.0.0.1:8080}"
android_base_url="$base_url"
timeout_sec="${MTAXI_LOCAL_BACKEND_TIMEOUT_SEC:-45}"
deadline=$((SECONDS + timeout_sec))
data_dir="${MTAXI_LOCAL_JSON_DATA_DIR:-$root_dir/server/data}"
upload_dir="${MTAXI_LOCAL_JSON_UPLOAD_DIR:-$root_dir/server/uploads}"
base_url_port="$(printf '%s\n' "$base_url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/:]+|\[[^]]+\]):([0-9]+).*#\2#')"
if [ "$base_url_port" = "$base_url" ]; then
  base_url_port="8080"
fi
port="${PORT:-$base_url_port}"

case "$android_base_url" in
  http://127.0.0.1:*|https://127.0.0.1:*)
    android_base_url="${android_base_url/127.0.0.1/10.0.2.2}"
    ;;
  http://localhost:*|https://localhost:*)
    android_base_url="${android_base_url/localhost/10.0.2.2}"
    ;;
esac

fail() {
  echo "MTaxi local JSON backend failed: $*" >&2
  exit 1
}

if ! command -v node >/dev/null 2>&1; then
  fail "node is required"
fi

if ! command -v curl >/dev/null 2>&1; then
  fail "curl is required"
fi

mkdir -p "$data_dir" "$upload_dir"

cd "$root_dir/server"

export NODE_ENV=development
export PORT="$port"
export MTAXI_STORE=json
export MTAXI_DATA_DIR="$data_dir"
export MTAXI_UPLOAD_DIR="$upload_dir"
export MTAXI_PUBLIC_BASE_URL="$base_url"
export MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL=true
export MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL=true
export MTAXI_SMS_PROVIDER=local
export MTAXI_ALLOW_LOCAL_SMS=true
export MTAXI_SMS_DEV_RETURN_CODE=true
if [ -z "${MTAXI_PAYMENT_PROVIDER:-}" ]; then
  if [ -n "${MTAXI_PAYMENT_URL_TEMPLATE:-}" ]; then
    export MTAXI_PAYMENT_PROVIDER=redirect
  else
    export MTAXI_PAYMENT_PROVIDER=kassa24
  fi
fi
export MTAXI_ALLOW_LOCAL_PAYMENT="${MTAXI_ALLOW_LOCAL_PAYMENT:-false}"
export MTAXI_FCM_ENABLED=false
export MTAXI_ALLOW_SIMULATED_PUSH=true

npm run start &
backend_pid="$!"

cleanup() {
  kill "$backend_pid" >/dev/null 2>&1 || true
  wait "$backend_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "Waiting for MTaxi local JSON backend: $base_url/readyz"
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

echo "MTaxi local JSON backend ready: $base_url"
echo "Data dir: $data_dir"
echo "Uploads dir: $upload_dir"
"$root_dir/scripts/print_local_flutter_commands.sh" "$base_url"
echo "Press Ctrl+C to stop backend."

wait "$backend_pid"
