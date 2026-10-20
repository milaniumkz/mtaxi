#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/output}"
pointer_path="$output_dir/LATEST_MTAXI_VPS_HANDOFF.txt"

fail() {
  echo "MTaxi latest VPS handoff pointer check failed: $*" >&2
  exit 1
}

[ -d "$output_dir" ] || fail "output directory not found: $output_dir"
[ -f "$pointer_path" ] || fail "missing latest handoff pointer: $pointer_path"

latest_output="$("$root_dir/scripts/latest_vps_handoff.sh" "$output_dir")"
latest_dir="$(printf '%s\n' "$latest_output" | awk -F': ' '/Latest verified MTaxi VPS handoff/ {print $2}')"
latest_archive="$(printf '%s\n' "$latest_output" | awk -F': ' '/Source archive/ {print $2}')"

pointer_dir="$(awk -F': ' '/Latest verified MTaxi VPS handoff/ {print $2}' "$pointer_path")"
pointer_archive="$(awk -F': ' '/Source archive/ {print $2}' "$pointer_path")"

[ -n "$latest_dir" ] || fail "latest helper did not print a handoff path"
[ -n "$latest_archive" ] || fail "latest helper did not print a source archive"
[ "$pointer_dir" = "$latest_dir" ] || fail "pointer path is stale: $pointer_dir != $latest_dir"
[ "$pointer_archive" = "$latest_archive" ] || fail "pointer archive is stale: $pointer_archive != $latest_archive"

"$root_dir/scripts/check_latest_vps_handoff_current.sh" "$latest_dir" >/dev/null

echo "MTaxi latest VPS handoff pointer is current: $pointer_path"
