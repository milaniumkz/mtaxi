#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
handoff_dir="${1:-}"
vps_user="${MTAXI_VPS_USER:-root}"
vps_host="${MTAXI_VPS_HOST:-YOUR_VPS_IP_OR_DOMAIN}"
remote_dir="${MTAXI_VPS_HANDOFF_REMOTE_DIR:-/tmp/mtaxi-handoff}"

fail() {
  echo "MTaxi VPS upload command print failed: $*" >&2
  exit 1
}

if [ -z "$handoff_dir" ]; then
  handoff_dir="$("$root_dir/scripts/latest_vps_handoff.sh" | awk -F': ' '/Latest verified MTaxi VPS handoff/ {print $2}')"
fi

[ -n "$handoff_dir" ] || fail "handoff directory was not resolved"
"$root_dir/scripts/verify_vps_handoff.sh" "$handoff_dir" >/dev/null
"$root_dir/scripts/check_latest_vps_handoff_current.sh" "$handoff_dir" >/dev/null

cat <<EOF
# Fill real VPS values, then run:
export MTAXI_VPS_USER=$vps_user
export MTAXI_VPS_HOST=$vps_host
export MTAXI_VPS_HANDOFF_REMOTE_DIR=$remote_dir

ssh "\$MTAXI_VPS_USER@\$MTAXI_VPS_HOST" "rm -rf '\$MTAXI_VPS_HANDOFF_REMOTE_DIR' && mkdir -p '\$MTAXI_VPS_HANDOFF_REMOTE_DIR'"
scp "$handoff_dir"/* "\$MTAXI_VPS_USER@\$MTAXI_VPS_HOST:\$MTAXI_VPS_HANDOFF_REMOTE_DIR/"
ssh "\$MTAXI_VPS_USER@\$MTAXI_VPS_HOST" "cd '\$MTAXI_VPS_HANDOFF_REMOTE_DIR' && chmod +x verify_vps_handoff.sh && shasum -a 256 -c mtaxi-source-*.tar.gz.sha256 && ./verify_vps_handoff.sh ."
EOF
