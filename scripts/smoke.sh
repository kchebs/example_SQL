#!/usr/bin/env bash
# Run sports-league SQL smoke assertions.
# Prefers Docker Compose when a daemon is available; otherwise uses local psql/Postgres.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

run_psql_file() {
  local url="$1"
  psql "$url" -v ON_ERROR_STOP=1 -f tests/sports_smoke.sql
}

if docker info >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
  else
    COMPOSE=()
  fi
  if [ "${#COMPOSE[@]}" -gt 0 ]; then
    echo "Using Docker Compose..."
    "${COMPOSE[@]}" up -d --wait
    "${COMPOSE[@]}" exec -T db psql -U example -d example_sql -v ON_ERROR_STOP=1 -f - < tests/sports_smoke.sql
    echo "example_SQL docker smoke passed"
    exit 0
  fi
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "Neither Docker daemon nor psql is available." >&2
  echo "Start Docker Desktop / Colima, or install Postgres (e.g. brew install postgresql@16)." >&2
  exit 1
fi

echo "Docker daemon unavailable; using local Postgres..."
DB_URL="${EXAMPLE_SQL_DATABASE_URL:-postgresql://example:example@127.0.0.1:5432/example_sql}"

# Best-effort local bootstrap (Homebrew Postgres)
if command -v brew >/dev/null 2>&1; then
  brew services start postgresql@16 >/dev/null 2>&1 || brew services start postgresql >/dev/null 2>&1 || true
fi
# create role/db if missing (ignore errors if already exist)
createuser -s example 2>/dev/null || true
psql postgres -v ON_ERROR_STOP=0 -c "CREATE ROLE example LOGIN PASSWORD 'example';" 2>/dev/null || true
psql postgres -v ON_ERROR_STOP=0 -c "CREATE DATABASE example_sql OWNER example;" 2>/dev/null || true

# load schema+seed fresh
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
psql "$DB_URL" -v ON_ERROR_STOP=1 -f docker/init/01_schema.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f docker/init/02_seed.sql
run_psql_file "$DB_URL"
echo "example_SQL local Postgres smoke passed"
