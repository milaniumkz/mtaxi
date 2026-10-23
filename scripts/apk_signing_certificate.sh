#!/usr/bin/env bash

# New apksigner versions label signers by scheme (V2/V3) or SDK ranges.
# Accept repeated ranges only when every reported signer has the same certificate.
mtaxi_apk_certificate_sha256() {
  local certificates
  certificates="$(sed -n -E 's/^(Signer|V[0-9.]+ Signer).* certificate SHA-256 digest: ([[:xdigit:]]{64})$/\2/p' | tr 'A-F' 'a-f' | sort -u)"
  [[ "$certificates" =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '%s\n' "$certificates"
}
