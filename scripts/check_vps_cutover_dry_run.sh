#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
handoff_dir="${1:-}"

fail() {
  echo "MTaxi VPS cutover dry-run failed: $*" >&2
  exit 1
}

if [ -z "$handoff_dir" ]; then
  handoff_dir="$("$root_dir/scripts/latest_vps_handoff.sh" | awk -F': ' '/Latest verified MTaxi VPS handoff/ {print $2}')"
fi

[ -n "$handoff_dir" ] || fail "handoff directory was not resolved"

"$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir" >/dev/null ||
  fail "handoff verification failed"
"$root_dir/scripts/print_vps_upload_commands.sh" "$handoff_dir" >/dev/null ||
  fail "VPS upload commands failed"
"$root_dir/scripts/check_vps_handoff_extract_smoke.sh" "$handoff_dir" >/dev/null ||
  fail "handoff extract smoke failed"

echo "MTaxi VPS cutover dry-run passed: $handoff_dir"
