#!/usr/bin/env bash
set -euo pipefail
umask 077
cd /opt/mtaxi
test -f .git-deploy-managed
test -f server/.env
install -d -m 700 /etc/mtaxi /var/lib/mtaxi/kaspi-pos /var/backups/mtaxi/config
key_file=/etc/mtaxi/kaspi-pos.key
if [[ ! -e "$key_file" ]]; then
  openssl rand -hex 32 > "$key_file.tmp"
  chmod 600 "$key_file.tmp"
  mv "$key_file.tmp" "$key_file"
fi
[[ -f "$key_file" && ! -L "$key_file" ]]
chmod 600 "$key_file"
# Validate format without printing key material; never rotate an existing key.
python3 - "$key_file" <<'PY'
from pathlib import Path
import re,sys
if not re.fullmatch(r'[0-9a-fA-F]{64}', Path(sys.argv[1]).read_text().strip()):
    raise SystemExit('Invalid existing Kaspi encryption key; not overwritten')
PY
cp -p server/.env "/var/backups/mtaxi/config/env-before-kaspi-$(date -u +%Y%m%dT%H%M%SZ)"
if ! grep -q '^MTAXI_KASPI_POS_ENABLED=' server/.env; then
  printf '\nMTAXI_KASPI_POS_ENABLED=true\n' >> server/.env
fi
if ! grep -q '^MTAXI_KASPI_POS_AUTO_INVOICES=' server/.env; then
  printf 'MTAXI_KASPI_POS_AUTO_INVOICES=true\n' >> server/.env
fi
printf 'Kaspi server-only encrypted storage prepared; no bank login or invoice requested.\n'
