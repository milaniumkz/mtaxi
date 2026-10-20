#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
handoff_dir="${1:-}"

fail() {
  echo "MTaxi VPS handoff extract smoke failed: $*" >&2
  exit 1
}

if [ -z "$handoff_dir" ]; then
  handoff_dir="$("$root_dir/scripts/latest_vps_handoff.sh" | awk -F': ' '/Latest verified MTaxi VPS handoff/ {print $2}')"
fi

[ -n "$handoff_dir" ] || fail "handoff directory was not resolved"
"$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir" >/dev/null ||
  fail "handoff verification failed before extract: $handoff_dir"

archive_name="$(
  find "$handoff_dir" -maxdepth 1 -type f -name 'mtaxi-source-*.tar.gz' -print |
    xargs -n 1 basename |
    sort |
    tail -n 1
)"
[ -n "$archive_name" ] || fail "source archive not found in $handoff_dir"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

tar -xzf "$handoff_dir/$archive_name" -C "$tmp_dir"

required_paths=(
  scripts/check_backend_transfer_steps.sh
  scripts/check_local_flutter_commands.sh
  scripts/check_vps_inputs.sh
  scripts/generate_production_env.sh
  deploy/predeploy_check.sh
  deploy/vps_prereq_check.sh
  server/package.json
)

for required in "${required_paths[@]}"; do
  [ -f "$tmp_dir/$required" ] || fail "extracted source missing $required"
done

bash -n \
  "$tmp_dir/scripts/check_backend_transfer_steps.sh" \
  "$tmp_dir/scripts/check_local_flutter_commands.sh" \
  "$tmp_dir/scripts/check_vps_inputs.sh" \
  "$tmp_dir/scripts/generate_production_env.sh" \
  "$tmp_dir/deploy/predeploy_check.sh" \
  "$tmp_dir/deploy/vps_prereq_check.sh"

(cd "$tmp_dir" && ./scripts/check_backend_transfer_steps.sh >/dev/null)
(cd "$tmp_dir" && ./scripts/check_local_flutter_commands.sh >/dev/null)

echo "MTaxi VPS handoff extract smoke passed: $handoff_dir"
