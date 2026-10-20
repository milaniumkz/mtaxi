#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/output}"

fail() {
  echo "MTaxi latest VPS handoff failed: $*" >&2
  exit 1
}

[ -d "$output_dir" ] || fail "output directory not found: $output_dir"

latest_dir=""
found=0
broken=0

while IFS= read -r candidate_dir; do
  [ -n "$candidate_dir" ] || continue
  found=$((found + 1))
  if "$root_dir/scripts/verify_vps_handoff.sh" "$candidate_dir" >/dev/null 2>&1; then
    latest_dir="$candidate_dir"
    break
  fi
  broken=$((broken + 1))
  echo "Skipping broken MTaxi VPS handoff: $candidate_dir" >&2
done < <(find "$output_dir" -maxdepth 1 -type d -name 'mtaxi-vps-handoff-*' -print | sort -r)

[ "$found" -gt 0 ] || fail "no mtaxi-vps-handoff-* directories found in $output_dir"
[ -n "$latest_dir" ] || fail "no verified mtaxi-vps-handoff-* directories found in $output_dir"

archive_name="$(
  find "$latest_dir" -maxdepth 1 -type f -name 'mtaxi-source-*.tar.gz' -print |
    xargs -n 1 basename |
    sort |
    tail -n 1
)"

[ -n "$archive_name" ] || fail "verified handoff has no source archive: $latest_dir"

echo "Latest verified MTaxi VPS handoff: $latest_dir"
echo "Source archive: $archive_name"
if [ "$broken" -gt 0 ]; then
  echo "Skipped broken newer packages: $broken"
fi
