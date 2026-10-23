#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_file="${1:-$root_dir/docs/vps_inputs.template.env}"
. "$root_dir/scripts/remote_backend_url_guard.sh"

fail() {
  echo "MTaxi VPS inputs check failed: $*" >&2
  exit 1
}

[ -f "$input_file" ] || fail "input file not found: $input_file"

set -a
# shellcheck disable=SC1090
. "$input_file"
set +a

normalize() {
  printf '%s' "${1:-}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_placeholder() {
  local value
  value="$(normalize "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [ -z "$value" ] ||
    [ "$value" = "false" ] ||
    [ "$value" = "https://sms-provider.example/send" ] ||
    [ "$value" = "https://pay-provider.example/start?invoice={{paymentid}}&amount={{amount}}" ] ||
    [ "$value" = "https://api.example.kz" ] ||
    printf '%s' "$value" | grep -Eq 'replace-with|change-this|example'
}

require_value() {
  local name="$1"
  local value="${!name:-}"
  ! is_placeholder "$value" || fail "$name is required"
}

require_true() {
  local name="$1"
  local value
  value="$(normalize "${!name:-}" | tr '[:upper:]' '[:lower:]')"
  [ "$value" = "true" ] || fail "$name must be true"
}

require_remote_url() {
  local name="$1"
  require_value "$name"
  mtaxi_validate_remote_backend_url "${!name}" "MTaxi VPS inputs check failed" >/dev/null
}

require_value MTAXI_VPS_HOST
require_value MTAXI_VPS_USER
require_value MTAXI_API_DOMAIN
require_remote_url MTAXI_PUBLIC_BASE_URL
require_value MTAXI_CORS_ORIGINS

public_base_host="$(
  MTAXI_URL="$MTAXI_PUBLIC_BASE_URL" node -e "
    try {
      process.stdout.write(new URL(process.env.MTAXI_URL).hostname);
    } catch (_) {
      process.exit(1);
    }
  "
)" || fail "MTAXI_PUBLIC_BASE_URL must be a valid URL"

if [ "$(normalize "$MTAXI_API_DOMAIN" | tr '[:upper:]' '[:lower:]')" != \
  "$(normalize "$public_base_host" | tr '[:upper:]' '[:lower:]')" ]; then
  fail "MTAXI_API_DOMAIN must match MTAXI_PUBLIC_BASE_URL host"
fi

require_true MTAXI_DNS_READY
require_true MTAXI_HTTPS_READY

IFS=',' read -r -a cors_origins <<<"$MTAXI_CORS_ORIGINS"
[ "${#cors_origins[@]}" -ge 2 ] ||
  fail "MTAXI_CORS_ORIGINS must include user web and admin web origins"
for cors_origin in "${cors_origins[@]}"; do
  cors_origin="$(normalize "$cors_origin")"
  [ -n "$cors_origin" ] || fail "MTAXI_CORS_ORIGINS contains an empty origin"
  case "$cors_origin" in
    https://*) ;;
    *) fail "MTAXI_CORS_ORIGINS must contain only external https:// origins" ;;
  esac
  case "$cors_origin" in
    *localhost*|*127.0.0.1*|*10.0.2.2*|*10.*|*192.168.*)
      fail "MTAXI_CORS_ORIGINS must not contain local, emulator or LAN origins"
      ;;
  esac
done

# Phone + password authentication does not require an SMS provider.

require_remote_url MTAXI_PAYMENT_URL_TEMPLATE
case "$MTAXI_PAYMENT_URL_TEMPLATE" in
  *'{{paymentId}}'*'{{amount}}'*) ;;
  *) fail "MTAXI_PAYMENT_URL_TEMPLATE must contain {{paymentId}} and {{amount}}" ;;
esac
require_value MTAXI_PAYMENT_CALLBACK_SECRET

if is_placeholder "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" &&
  is_placeholder "${GOOGLE_APPLICATION_CREDENTIALS:-}"; then
  fail "FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS is required for FCM push"
fi

require_value MTAXI_ADMIN_PHONE
require_value MTAXI_ADMIN_PASSWORD
require_value MTAXI_ADMIN_NAME
require_value MTAXI_ADMIN_CITY

admin_digits="$(printf '%s' "$MTAXI_ADMIN_PHONE" | tr -cd '0-9')"
if [ "$admin_digits" = "70000000000" ] ||
  { [ "${#admin_digits}" -ne 10 ] && [ "${#admin_digits}" -ne 11 ]; }; then
  fail "MTAXI_ADMIN_PHONE must be a real phone number"
fi

[ "${#MTAXI_ADMIN_PASSWORD}" -ge 6 ] ||
  fail "MTAXI_ADMIN_PASSWORD must be at least 6 characters"

echo "MTaxi VPS inputs check passed: $input_file"
