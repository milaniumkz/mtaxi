#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/output}"
mode="${2:---dry-run}"

fail() {
  echo "MTaxi output handoff cleanup failed: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/cleanup_output_handoffs.sh [output_dir] [--dry-run|--delete]

Checks output/mtaxi-vps-handoff-* packages and removes only broken old
handoff directories when --delete is passed. The latest handoff is never
deleted by this helper.
USAGE
}

case "$mode" in
  --dry-run|--delete) ;;
  *) usage; fail "unknown mode: $mode" ;;
esac

[ -d "$output_dir" ] || fail "output directory not found: $output_dir"

latest_dir="$(find "$output_dir" -maxdepth 1 -type d -name 'mtaxi-vps-handoff-*' -print | sort | tail -1)"
[ -n "$latest_dir" ] || fail "no mtaxi-vps-handoff-* directories found in $output_dir"

broken_old=0
valid=0

while IFS= read -r handoff_dir; do
  [ -n "$handoff_dir" ] || continue
  if "$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir" >/dev/null 2>&1; then
    valid=$((valid + 1))
    echo "KEEP valid $handoff_dir"
    continue
  fi

  if [ "$handoff_dir" = "$latest_dir" ]; then
    echo "KEEP latest-broken $handoff_dir"
    continue
  fi

  broken_old=$((broken_old + 1))
  if [ "$mode" = "--delete" ]; then
    rm -rf "$handoff_dir"
    echo "DELETED broken-old $handoff_dir"
  else
    echo "WOULD_DELETE broken-old $handoff_dir"
  fi
done < <(find "$output_dir" -maxdepth 1 -type d -name 'mtaxi-vps-handoff-*' -print | sort)

[ "$valid" -gt 0 ] || fail "no valid handoff packages found"

if [ "$mode" = "--delete" ]; then
  echo "MTaxi output handoff cleanup complete: deleted $broken_old broken old package(s)"
else
  echo "MTaxi output handoff cleanup dry-run: $broken_old broken old package(s)"
fi
