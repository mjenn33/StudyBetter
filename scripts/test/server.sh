#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
container="studybetter-test-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
# Docker assigns an unused host port; every run has its own disposable database.
docker run --detach --name "$container" -e POSTGRES_USER=studybetter -e POSTGRES_PASSWORD=studybetter -e POSTGRES_DB=studybetter -p 127.0.0.1::5432 postgres:17-alpine >/dev/null
for attempt in {1..60}; do
  if docker exec "$container" pg_isready -U studybetter -d studybetter >/dev/null 2>&1; then break; fi
  sleep 1
done
port="$(docker port "$container" 5432/tcp | cut -d: -f2)"
export TEST_DATABASE_URL="postgres://studybetter:studybetter@127.0.0.1:$port/studybetter"
cd server
dart test
