-- dbt-style layer examples for the healthcare domain (reference only; not loaded by docker init).
-- Fixed as-of date: DATE '2019-01-01' (matches tests/healthcare_smoke.sql).
-- See docs/dbt_style_layering.md

-- staging
-- stg_accounts
SELECT
  account_id,
  account_created_date,
  pcah_eligible
FROM accounts;

-- stg_pcah_reg
SELECT
  account_id,
  pcah_reg_date
FROM pcah_reg;

-- intermediate: eligible accounts with optional registration + latency
-- int_eligible_registrations
SELECT
  a.account_id,
  a.account_created_date,
  a.pcah_eligible,
  g.pcah_reg_date,
  CASE
    WHEN g.pcah_reg_date IS NOT NULL
    THEN (g.pcah_reg_date - a.account_created_date)
  END AS latency_days
FROM accounts a
LEFT JOIN pcah_reg g ON a.account_id = g.account_id;

-- mart: PCAH funnel KPIs as of 2019-01-01
-- mart_pcah_funnel
SELECT
  (
    SELECT COUNT(*)
    FROM accounts
    WHERE account_created_date >= DATE '2019-01-01' - INTERVAL '1 year'
  ) AS accounts_created_prior_year,
  (
    SELECT
      SUM(CASE WHEN g.pcah_reg_date IS NOT NULL THEN 1 ELSE 0 END)::NUMERIC
      / NULLIF(SUM(CASE WHEN a.pcah_eligible THEN 1 ELSE 0 END), 0)
    FROM accounts a
    LEFT JOIN pcah_reg g ON a.account_id = g.account_id
  ) AS eligible_registration_rate,
  (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY (g.pcah_reg_date - a.account_created_date)
    )
    FROM accounts a
    JOIN pcah_reg g ON a.account_id = g.account_id
    WHERE EXTRACT(YEAR FROM g.pcah_reg_date) = 2018
  ) AS median_latency_days_2018;
