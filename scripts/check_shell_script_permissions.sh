#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "MTaxi shell script permissions check failed: $*" >&2
  exit 1
}

missing_exec="$(
  find "$root_dir/scripts" "$root_dir/deploy" -type f -name '*.sh' ! -perm -111 -print |
    sed "s#^$root_dir/##" |
    sort
)"

if [ -n "$missing_exec" ]; then
  fail "scripts must be executable:
$missing_exec"
fi

echo "MTaxi shell script permissions check passed"
