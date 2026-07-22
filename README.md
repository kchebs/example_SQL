# SQL Analytics Examples

Personal collection of SQL problem-solving for analytics work: window functions, funnel metrics, KPI reporting, healthcare scheduling, ecommerce orders, and mobile-game marketing metrics.

Company names in prompts are **genericized**. Query logic and schemas are preserved.

## Project overview

| Area | What it covers |
|------|----------------|
| Streaming analytics | Country/stream volume, monthly averages, device mix |
| Window functions | Rows-to-columns pivots, top-N percent |
| Product KPIs | Software deployment / business KPI analysis |
| Healthcare scheduling | Account signup latency, GP utilization-style questions |
| Trial conversion | Ad impression → trial conversion patterns |
| Sports league | Multi-sport participation, pivots, incentive exports |
| Ecommerce orders | Shipments, refunds, YoY monthly order counts |
| Mobile marketing | Cohorts, retention, ARPU/ARPPU, creative CTR/IPM |

## Problem framing

Ambiguous product questions need clear assumptions, correct joins, and efficient SQL. Each file documents those choices next to the query.

## Approach

Each `.sql` / `.SQL` file answers a business prompt with readable queries and comments. Narrative walkthroughs live under `docs/`.

## Architecture

```mermaid
flowchart LR
  Prompt[Business_Prompt] --> Schema[Assumed_Tables]
  Schema --> Query[SQL_Solution]
  Query --> Insight[Metric_or_Answer]
```

## Repository layout

```
example_SQL/
├── README.md
├── docker-compose.yml
├── docker/init/          # Postgres schema + seed
├── scripts/smoke.sh
├── tests/sports_smoke.sql
├── sql/
│   ├── Business_KPI_Analysis_on_Software_Deployment.SQL
│   ├── Rows_to_Columns_Window_Functions.SQL
│   ├── Top_N__Percent_of_X.SQL
│   ├── streaming_trial_conversion.sql
│   ├── sports_league_queries.sql
│   ├── ecommerce_order_analytics.sql
│   ├── mobile_game_cohort_and_ads.sql
│   └── healthcare_scheduling.sql
└── docs/
    ├── DETAILED_SQL_WALKTHROUGH.md
    ├── sports_league_sql.md
    ├── ecommerce_order_sql.md
    └── mobile_game_marketing_analytics.md
```

## Technologies

- SQL (ANSI-style with occasional warehouse dialects such as `DATEADD` / `GETDATE()` noted in comments)
- Analytics patterns: aggregates, CTEs, window functions (`ROW_NUMBER`, ranking)

## Installation / usage

Open any file under [`sql/`](sql/) in your SQL client, or run the **Postgres docker smoke** (sports league Q1–Q3 with assertions):

```bash
chmod +x scripts/smoke.sh
./scripts/smoke.sh
# equivalent:
# docker compose up -d --wait
# docker compose exec -T db psql -U example -d example_sql -v ON_ERROR_STOP=1 -f - < tests/sports_smoke.sql
```

Requires Docker **or** a local Postgres. Prefer Docker when available:

```bash
docker compose up -d --wait
docker compose exec -T db ...
```

If Docker is unavailable, `scripts/smoke.sh` falls back to local `psql` (e.g. `brew install postgresql@16`) and loads `docker/init/*.sql` before assertions.

Long-form prompt walkthroughs:

- Streaming + healthcare: [`docs/DETAILED_SQL_WALKTHROUGH.md`](docs/DETAILED_SQL_WALKTHROUGH.md)
- Sports league: [`docs/sports_league_sql.md`](docs/sports_league_sql.md)
- Ecommerce orders: [`docs/ecommerce_order_sql.md`](docs/ecommerce_order_sql.md)
- Mobile marketing: [`docs/mobile_game_marketing_analytics.md`](docs/mobile_game_marketing_analytics.md)

Example — highest-stream country in the last 7 days (streaming schema):

```sql
SELECT customer_country,
       COUNT(DISTINCT stream_id) AS number_of_streams
FROM streams
WHERE playback_date >= DATEADD(day, -7, GETDATE())
GROUP BY customer_country
ORDER BY COUNT(DISTINCT stream_id) DESC
LIMIT 1;
```

## Example outputs

Queries return scalar KPIs or small result sets (country rankings, monthly averages, medians). Exact numeric outputs depend on the sample tables assumed in each prompt.

## Product decisions and tradeoffs

- Prefer **explicit assumptions** in comments over hidden edge-case handling.
- Some prompts use warehouse-specific date functions; equivalents exist in Postgres (`CURRENT_DATE - INTERVAL '7 days'`).
- Docs may reference older wording; treat `sql/` as source of truth for query logic.

## Future improvements

- Extend docker seeds/assertions beyond sports league (ecommerce, healthcare)
- Provide dialect variants (Postgres / BigQuery / Snowflake) side by side
- Add `sqlfluff` linting in CI

## License

Personal portfolio examples. Not affiliated with any employer.
