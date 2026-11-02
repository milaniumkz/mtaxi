# Kaspi POS adapter

Protocol/cryptographic primitives adapted from https://github.com/tapter-dev/kaspi-pos-automation at commit 9b0000d38716a7c4b36867a5642a4768a3a4552f (MIT; original notice in LICENSE).

This is third-party automation of Kaspi Pay's mobile protocol, not a claim of an official Kaspi partner integration. Bank-side changes, extra identity checks, app-version minimums and cashier permissions can prevent login; no authentication checks are bypassed.

MTaxi changes: no public demo server or browser-carried bank session; server-only encrypted vault, admin authorization, per-owner temporary login challenge, bounded/allowlisted HTTPS requests, no raw request/response logging, explicit invoice creation tied to an existing top-up, persistent ambiguity/deduplication, amount/phone/operation/organization checks. No upstream polling, webhook broadcasts, refunds or unattended money crediting are enabled. Payment credit remains a separate admin action after verified payment.

The original stateless client token model and unredacted logs were not copied. Normal TLS validation and any inherited proxy/CA configuration are retained. One backend instance owns the connection, matching the current deployment. The vault encryption key and session data must remain outside Git and public web directories.
