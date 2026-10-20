#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/output}"

fail() {
  echo "MTaxi output handoff check failed: $*" >&2
  exit 1
}

[ -d "$output_dir" ] || fail "output directory not found: $output_dir"

found=0
valid=0
invalid=0
latest_dir=""
latest_status=""

while IFS= read -r handoff_dir; do
  [ -n "$handoff_dir" ] || continue
  found=$((found + 1))
  if "$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir" >/dev/null 2>&1; then
    valid=$((valid + 1))
    latest_status="ok"
    echo "OK $handoff_dir"
  else
    invalid=$((invalid + 1))
    latest_status="broken"
    echo "BROKEN $handoff_dir"
  fi
  latest_dir="$handoff_dir"
done < <(find "$output_dir" -maxdepth 1 -type d -name 'mtaxi-vps-handoff-*' -print | sort)

[ "$found" -gt 0 ] || fail "no mtaxi-vps-handoff-* directories found in $output_dir"
[ "$valid" -gt 0 ] || fail "no valid handoff packages found"

if [ "${MTAXI_OUTPUT_HANDOFF_REQUIRE_ALL:-false}" = "true" ]; then
  [ "$invalid" -eq 0 ] || fail "$invalid of $found handoff packages are broken"
fi

[ "$latest_status" = "ok" ] || fail "latest handoff package is broken: $latest_dir"

echo "MTaxi output handoff check passed: $valid valid package(s), $invalid broken old package(s)"
