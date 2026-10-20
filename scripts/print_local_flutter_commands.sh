#!/usr/bin/env bash
set -euo pipefail

base_url="${MTAXI_LOCAL_BACKEND_URL:-${1:-http://127.0.0.1:8080}}"
android_base_url="$base_url"

case "$android_base_url" in
  http://127.0.0.1:*|https://127.0.0.1:*)
    android_base_url="${android_base_url/127.0.0.1/10.0.2.2}"
    ;;
  http://localhost:*|https://localhost:*)
    android_base_url="${android_base_url/localhost/10.0.2.2}"
    ;;
esac

echo "MTaxi local backend: $base_url"
echo "Check backend contract:"
echo "  ./scripts/check_local_backend_contract.sh $base_url"
echo "Flutter:"
echo "  web:     flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=$base_url"
echo "  android: flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=$android_base_url"
