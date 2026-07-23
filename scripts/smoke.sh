#!/usr/bin/env bash
# Run multi-domain SQL smoke assertions (data-quality, sports, ecommerce, healthcare),
# then offline-first NL2SQL golden eval.
# Prefers Docker Compose when a daemon is available; otherwise uses local psql/Postgres.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SMOKE_FILES=(
  tests/data_quality_smoke.sql
  tests/sports_smoke.sql
  tests/ecommerce_smoke.sql
  tests/healthcare_smoke.sql
)

run_smoke_files() {
  local runner=("$@")
  local f
  for f in "${SMOKE_FILES[@]}"; do
    echo "Running $f ..."
    "${runner[@]}" < "$f"
  done
}

run_nl2sql_eval() {
  echo "Running NL2SQL eval ..."
  local py=python3
  if [ -x "$ROOT/.venv/bin/python" ]; then
    py="$ROOT/.venv/bin/python"
  elif [ -x "$ROOT/.venv/bin/python3" ]; then
    py="$ROOT/.venv/bin/python3"
  fi
  "$py" "$ROOT/scripts/run_nl2sql_eval.py"
}

SQL_SMOKE_DONE=0

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
    run_smoke_files "${COMPOSE[@]}" exec -T db psql -U example -d example_sql -v ON_ERROR_STOP=1 -f -
    echo "sql-analytics-platform docker smoke passed (data-quality + sports + ecommerce + healthcare)"
    SQL_SMOKE_DONE=1
  fi
fi

if [ "$SQL_SMOKE_DONE" -eq 0 ]; then
  if ! command -v psql >/dev/null 2>&1; then
    echo "Neither Docker daemon nor psql is available." >&2
    echo "Start Docker Desktop / Colima, or install Postgres (e.g. brew install postgresql@16)." >&2
    exit 1
  fi

  echo "Docker daemon unavailable; using local Postgres..."
  DB_URL="${EXAMPLE_SQL_DATABASE_URL:-postgresql://example:example@127.0.0.1:5432/example_sql}"

  if command -v brew >/dev/null 2>&1; then
    brew services start postgresql@16 >/dev/null 2>&1 || brew services start postgresql >/dev/null 2>&1 || true
  fi
  createuser -s example 2>/dev/null || true
  psql postgres -v ON_ERROR_STOP=0 -c "CREATE ROLE example LOGIN PASSWORD 'example';" 2>/dev/null || true
  psql postgres -v ON_ERROR_STOP=0 -c "CREATE DATABASE example_sql OWNER example;" 2>/dev/null || true

  psql "$DB_URL" -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  for f in docker/init/*.sql; do
    echo "Loading $f ..."
    psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"
  done
  for f in "${SMOKE_FILES[@]}"; do
    echo "Running $f ..."
    psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"
  done
  echo "example_SQL local Postgres smoke passed (data-quality + sports + ecommerce + healthcare)"
fi

run_nl2sql_eval
echo "sql-analytics-platform smoke + nl2sql eval passed"
