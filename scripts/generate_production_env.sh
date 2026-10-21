#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-$root_dir/server/.env.generated}"
. "$root_dir/scripts/remote_backend_url_guard.sh"

fail() {
  echo "MTaxi production env generation failed: $*" >&2
  exit 1
}

require_env() {
  local name="$1"
  local value="${!name:-}"
  [ -n "$value" ] || fail "$name is required"
}

random_hex() {
  local bytes="$1"
  command -v openssl >/dev/null 2>&1 || fail "openssl is required"
  openssl rand -hex "$bytes"
}

require_env MTAXI_PUBLIC_BASE_URL
require_env MTAXI_PAYMENT_URL_TEMPLATE

mtaxi_validate_remote_backend_url "$MTAXI_PUBLIC_BASE_URL" "MTaxi production env generation failed" >/dev/null
mtaxi_validate_remote_backend_url "$MTAXI_PAYMENT_URL_TEMPLATE" "MTaxi production env generation failed" >/dev/null

case "$MTAXI_PAYMENT_URL_TEMPLATE" in
  *'{{paymentId}}'*'{{amount}}'*) ;;
  *) fail "MTAXI_PAYMENT_URL_TEMPLATE must contain {{paymentId}} and {{amount}}" ;;
esac

if [ -z "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" ] && [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  fail "FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS is required for production FCM"
fi

seed_admin_on_start="${MTAXI_SEED_ADMIN_ON_START:-false}"
case "$(printf '%s' "$seed_admin_on_start" | tr '[:upper:]' '[:lower:]')" in
  true)
    require_env MTAXI_ADMIN_PHONE
    require_env MTAXI_ADMIN_PASSWORD
    require_env MTAXI_ADMIN_NAME
    require_env MTAXI_ADMIN_CITY
    admin_digits="$(printf '%s' "$MTAXI_ADMIN_PHONE" | tr -cd '0-9')"
    if [ "$admin_digits" = "70000000000" ] ||
      { [ "${#admin_digits}" -ne 10 ] && [ "${#admin_digits}" -ne 11 ]; }; then
      fail "MTAXI_ADMIN_PHONE must be a real phone number"
    fi
    [ "${#MTAXI_ADMIN_PASSWORD}" -ge 6 ] ||
      fail "MTAXI_ADMIN_PASSWORD must be at least 6 characters"
    ;;
  false) ;;
  *) fail "MTAXI_SEED_ADMIN_ON_START must be true or false" ;;
esac

postgres_password="${POSTGRES_PASSWORD:-$(random_hex 24)}"
token_secret="${MTAXI_TOKEN_SECRET:-$(random_hex 48)}"
payment_secret="${MTAXI_PAYMENT_CALLBACK_SECRET:-$(random_hex 32)}"

mkdir -p "$(dirname "$output_path")"

{
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      NODE_ENV=*) printf 'NODE_ENV=production\n' ;;
      MTAXI_PUBLIC_BASE_URL=*) printf 'MTAXI_PUBLIC_BASE_URL=%s\n' "$MTAXI_PUBLIC_BASE_URL" ;;
      MTAXI_TOKEN_SECRET=*) printf 'MTAXI_TOKEN_SECRET=%s\n' "$token_secret" ;;
      POSTGRES_PASSWORD=*) printf 'POSTGRES_PASSWORD=%s\n' "$postgres_password" ;;
      DATABASE_URL=*) printf 'DATABASE_URL=postgres://mtaxi:%s@postgres:5432/mtaxi\n' "$postgres_password" ;;
      MTAXI_SMS_PROVIDER=*) printf 'MTAXI_SMS_PROVIDER=disabled\n' ;;
      MTAXI_SMS_HTTP_*=*) printf '%s=\n' "${line%%=*}" ;;
      MTAXI_PAYMENT_URL_TEMPLATE=*) printf 'MTAXI_PAYMENT_URL_TEMPLATE=%s\n' "$MTAXI_PAYMENT_URL_TEMPLATE" ;;
      MTAXI_PAYMENT_CALLBACK_SECRET=*) printf 'MTAXI_PAYMENT_CALLBACK_SECRET=%s\n' "$payment_secret" ;;
      MTAXI_SEED_ADMIN_ON_START=*) printf 'MTAXI_SEED_ADMIN_ON_START=%s\n' "$seed_admin_on_start" ;;
      MTAXI_ADMIN_PHONE=*) printf 'MTAXI_ADMIN_PHONE=%s\n' "${MTAXI_ADMIN_PHONE:-+77000000000}" ;;
      MTAXI_ADMIN_PASSWORD=*) printf 'MTAXI_ADMIN_PASSWORD=%s\n' "${MTAXI_ADMIN_PASSWORD:-replace-with-admin-password}" ;;
      MTAXI_ADMIN_NAME=*) printf 'MTAXI_ADMIN_NAME=%s\n' "${MTAXI_ADMIN_NAME:-Администратор}" ;;
      MTAXI_ADMIN_CITY=*) printf 'MTAXI_ADMIN_CITY=%s\n' "${MTAXI_ADMIN_CITY:-Белоусовка}" ;;
      FIREBASE_PROJECT_ID=*) printf 'FIREBASE_PROJECT_ID=%s\n' "${FIREBASE_PROJECT_ID:-mtaxi-52990}" ;;
      FIREBASE_SERVICE_ACCOUNT_JSON=*) [ -n "${FIREBASE_SERVICE_ACCOUNT_JSON:-}${GOOGLE_APPLICATION_CREDENTIALS:-}" ] || printf '%s\n' "$line" ;;
      '# GOOGLE_APPLICATION_CREDENTIALS='*) [ -n "${FIREBASE_SERVICE_ACCOUNT_JSON:-}${GOOGLE_APPLICATION_CREDENTIALS:-}" ] || printf '%s\n' "$line" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$root_dir/server/.env.example"
  if [ -n "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" ]; then
    printf 'FIREBASE_SERVICE_ACCOUNT_JSON=%s\n' "$FIREBASE_SERVICE_ACCOUNT_JSON"
  elif [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    printf 'GOOGLE_APPLICATION_CREDENTIALS=%s\n' "$GOOGLE_APPLICATION_CREDENTIALS"
  fi
} >"$output_path"

echo "MTaxi production env generated: $output_path"
echo "Review SMS/payment/admin/FCM values, then copy to server/.env on VPS."
