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

Three domains ship with **Postgres seeds + smoke assertions** (sports, ecommerce, healthcare) so a clone can prove the logic end-to-end. Smoke also runs **data-quality** checks (unique / not_null / relationships / accepted_values) before metric assertions.

Layering follows a dbt-style source → staging → intermediate → mart contract (conceptual—no dbt install required). See [`docs/dbt_style_layering.md`](docs/dbt_style_layering.md).

## Architecture

```mermaid
flowchart LR
  Prompt[Business_Prompt] --> Schema[Assumed_Tables]
  Schema --> Query[SQL_Solution]
  Query --> Insight[Metric_or_Answer]
  Schema --> Seed[Docker_Seed]
  Seed --> DQ[Data_Quality_Smoke]
  DQ --> Smoke[Metric_Smoke_Assertions]
```

## Repository layout

```
example_SQL/
├── README.md
├── docker-compose.yml
├── docker/init/          # sports + ecommerce + healthcare schema/seed
├── scripts/smoke.sh
├── tests/
│   ├── data_quality_smoke.sql
│   ├── sports_smoke.sql
│   ├── ecommerce_smoke.sql
│   └── healthcare_smoke.sql
├── docs/fixtures/        # expected smoke result text
├── sql/
│   └── layers/           # dbt-style stg/int/mart reference SQL
└── docs/
    └── dbt_style_layering.md
```

## Technologies

- SQL (ANSI-style; warehouse dialects noted in comments)
- Postgres 16 (Docker Compose smoke)
- GitHub Actions CI (`./scripts/smoke.sh`)

## Installation / usage

```bash
chmod +x scripts/smoke.sh
./scripts/smoke.sh
```

Requires Docker **or** local Postgres. Prefer Docker when available.

Long-form walkthroughs:

- Streaming + healthcare: [`docs/DETAILED_SQL_WALKTHROUGH.md`](docs/DETAILED_SQL_WALKTHROUGH.md)
- Sports league: [`docs/sports_league_sql.md`](docs/sports_league_sql.md)
- Ecommerce orders: [`docs/ecommerce_order_sql.md`](docs/ecommerce_order_sql.md)
- Mobile marketing: [`docs/mobile_game_marketing_analytics.md`](docs/mobile_game_marketing_analytics.md)
- dbt-style layering: [`docs/dbt_style_layering.md`](docs/dbt_style_layering.md)

## Example outputs (smoke fixtures)

Data quality (PK uniqueness, FK relationships, accepted values):

```text
status
data_quality_smoke OK
```

Sports:

```text
status
sports_smoke OK
```

Ecommerce (NYC meal-kit lines on 2022-06-15 = 4; cash refund order 100 = 12.50):

```text
status
ecommerce_smoke OK
```

Healthcare (as-of 2019-01-01: prior-year accounts = 4; eligible reg rate = 0.75; median latency = 16 days):

```text
status
healthcare_smoke OK
```

Full fixture files: [`docs/fixtures/`](docs/fixtures/).

## Product decisions and tradeoffs

- Prefer **explicit assumptions** in comments over hidden edge-case handling.
- Smoke tests use Postgres-native date math; portfolio `.sql` files may show warehouse dialects (`DATEADD`, `GETDATE()`) with equivalents noted.
- Docs may reference older wording; treat `sql/` as source of truth for query logic.
- `sql/layers/` is reference SQL for staging/intermediate/mart shapes; Docker init seeds remain the executable source.

## License

Personal portfolio examples. Not affiliated with any employer. All Rights Reserved. See [LICENSE](LICENSE).
