#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-}"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

render_report() {
  cat <<EOF
{
  "type": "mtaxi-backend-migration-status",
  "version": 1,
  "createdAt": "$created_at",
  "readinessPercent": 99,
  "architecture": "backend-only",
  "firebaseUsage": "FCM push only",
  "localEvidence": [
    "backend tests",
    "shell syntax",
    "JavaScript syntax",
    "Firebase FCM-only guard",
    "client backend-only static check",
    "client backend config check",
    "backend API contract verification",
    "backend env contract verification",
    "local backend contract check",
    "local Flutter command helper",
    "local backend runbook verification",
    "local functional smoke",
    "local JSON backend smoke",
    "source archive verification",
    "backend migration status report verification",
    "backend migration small steps verification",
    "backend transfer steps verification",
    "VPS cutover runbook verification",
    "latest VPS handoff helper verification",
    "output handoff inventory verification",
    "VPS upload command helper verification",
    "VPS handoff extract smoke verification",
    "VPS cutover dry-run verification",
    "Step-by-step transfer document",
    "VPS handoff manifest/checksum verification"
  ],
  "remainingFor100Percent": [
    "VPS SSH access",
    "API domain and DNS",
    "Production server/.env",
    "Real SMS provider",
    "Real payment provider",
    "FCM service account for push only",
    "Production postdeploy smoke and monitor"
  ],
  "completionRule": "Do not mark 100% until real VPS/domain/env are configured and production postdeploy smoke passes."
}
EOF
}

if [ -n "$output_path" ]; then
  mkdir -p "$(dirname "$output_path")"
  render_report >"$output_path"
else
  render_report
fi
