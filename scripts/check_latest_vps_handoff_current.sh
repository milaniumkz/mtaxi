#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
handoff_dir="${1:-}"

fail() {
  echo "MTaxi latest VPS handoff current check failed: $*" >&2
  exit 1
}

if [ -z "$handoff_dir" ]; then
  latest_output="$("$root_dir/scripts/latest_vps_handoff.sh" "$root_dir/output")"
  handoff_dir="$(printf '%s\n' "$latest_output" | sed -n 's/^Latest verified MTaxi VPS handoff: //p' | tail -1)"
fi

[ -n "$handoff_dir" ] || fail "handoff path was not found"
[ -d "$handoff_dir" ] || fail "latest handoff directory does not exist: $handoff_dir"
"$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir" >/dev/null

archive_path="$(find "$handoff_dir" -maxdepth 1 -type f -name 'mtaxi-source-*.tar.gz' | sort | tail -1)"
[ -n "$archive_path" ] || fail "source archive is missing in $handoff_dir"

newer_source="$(
  find \
    "$root_dir/server" \
    "$root_dir/scripts" \
    "$root_dir/deploy" \
    "$root_dir/docs/backend_deployment_checklist.md" \
    "$root_dir/docs/backend_migration_plan.md" \
    "$root_dir/docs/backend_migration_small_steps.md" \
    "$root_dir/docs/backend_transfer_steps.md" \
    "$root_dir/docs/local_backend_runbook.md" \
    "$root_dir/docs/vps_cutover_runbook.md" \
    "$root_dir/docs/vps_inputs.template.env" \
    "$root_dir/docs/vps_required_inputs.md" \
    "$root_dir/lib/backend" \
    "$root_dir/pubspec.yaml" \
    "$root_dir/docker-compose.production.yml" \
    \( -path "$root_dir/server/node_modules" -o -path "$root_dir/server/data" -o -path "$root_dir/server/uploads" -o -path "$root_dir/server/test" \) -prune -o \
    -type f -newer "$archive_path" -print |
    sed "s#^$root_dir/##" |
    sort |
    head -20
)"

if [ -n "$newer_source" ]; then
  fail "latest handoff is older than source files:
$newer_source
Run: MTAXI_VPS_HANDOFF_SKIP_READY=true ./scripts/package_vps_handoff.sh output/mtaxi-vps-handoff-\$(date +%Y%m%d-%H%M%S)"
fi

echo "MTaxi latest VPS handoff is current: $handoff_dir"
