#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_url="${MTAXI_LOCAL_BACKEND_URL:-http://127.0.0.1:8080}"
android_base_url="$base_url"
timeout_sec="${MTAXI_LOCAL_BACKEND_TIMEOUT_SEC:-90}"
deadline=$((SECONDS + timeout_sec))
base_url_host="$(printf '%s\n' "$base_url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://(\[[^]]+\]|[^/:]+).*#\1#')"
base_url_port="$(printf '%s\n' "$base_url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/:]+|\[[^]]+\]):([0-9]+).*#\2#')"
if [ "$base_url_host" = "$base_url" ]; then
  base_url_host="127.0.0.1"
fi
if [ "$base_url_port" = "$base_url" ]; then
  base_url_port="8080"
fi
case "$base_url_host" in
  localhost)
    bind_host="127.0.0.1"
    ;;
  *)
    bind_host="$base_url_host"
    ;;
esac
compose_override="$(mktemp)"
compose_files=(-f docker-compose.backend.yml -f "$compose_override")

cleanup() {
  rm -f "$compose_override"
}
trap cleanup EXIT INT TERM

cat >"$compose_override" <<EOF
services:
  backend:
    ports:
      - "${bind_host}:${base_url_port}:8080"
    environment:
      MTAXI_PUBLIC_BASE_URL: "$base_url"
EOF

case "$android_base_url" in
  http://127.0.0.1:*|https://127.0.0.1:*)
    android_base_url="${android_base_url/127.0.0.1/10.0.2.2}"
    ;;
  http://localhost:*|https://localhost:*)
    android_base_url="${android_base_url/localhost/10.0.2.2}"
    ;;
esac

cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  echo "MTaxi local backend failed: docker is required" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "MTaxi local backend failed: docker compose is required" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "MTaxi local backend failed: curl is required" >&2
  exit 1
fi

docker compose "${compose_files[@]}" up -d --build

echo "Waiting for MTaxi backend: $base_url/readyz"
until curl -fsS "$base_url/readyz" >/dev/null 2>&1; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "MTaxi local backend failed: readiness timeout after ${timeout_sec}s" >&2
    docker compose "${compose_files[@]}" ps >&2 || true
    docker compose "${compose_files[@]}" logs --tail=80 backend >&2 || true
    exit 1
  fi
  sleep 2
done

(
  cd "$root_dir/server"
  MTAXI_SMOKE_ADMIN_PHONE=+77000000000 \
    MTAXI_SMOKE_ADMIN_PASSWORD=local-compose-admin-password \
    "$root_dir/scripts/check_local_backend_contract.sh" "$base_url" postgres
)

echo "MTaxi local backend ready: $base_url"
echo "Local admin:"
echo "  phone: +77000000000"
echo "  password: local-compose-admin-password"
"$root_dir/scripts/print_local_flutter_commands.sh" "$base_url"
