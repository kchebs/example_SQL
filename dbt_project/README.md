# Minimal dbt project (healthcare telehealth funnel)

Executable dbt models over the same Docker Postgres seed used by `scripts/smoke.sh`.

## Setup

```bash
# from example_SQL root — start Postgres
docker compose up -d

pip install dbt-postgres
export DBT_PROFILES_DIR="$(pwd)/dbt_project"
cp dbt_project/profiles.yml.example dbt_project/profiles.yml
cd dbt_project && dbt run --select mart_telehealth_funnel
```

Reference SQL that mirrors these layers without dbt remains in [`../sql/layers/healthcare_layers.sql`](../sql/layers/healthcare_layers.sql).
