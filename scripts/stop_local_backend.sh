#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  echo "MTaxi local backend stop failed: docker is required" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "MTaxi local backend stop failed: docker compose is required" >&2
  exit 1
fi

docker compose -f docker-compose.backend.yml down

echo "MTaxi local backend stopped"
echo "PostgreSQL and uploads volumes were kept. To remove them, run docker compose manually with -v."
