-- Healthcare smoke assertions (Postgres-portable).
-- Uses fixed as-of date DATE '2019-01-01' instead of GETDATE()/DATEADD.
\set ON_ERROR_STOP on

-- Accounts created in the year before as-of → ids 1,2,3,5 (not 4)
DO $$
DECLARE
  n INTEGER;
BEGIN
  SELECT COUNT(*) INTO n
  FROM accounts
  WHERE account_created_date >= DATE '2019-01-01' - INTERVAL '1 year';
  IF n IS DISTINCT FROM 4 THEN
    RAISE EXCEPTION 'accounts last-year expected 4 got %', n;
  END IF;
END $$;

-- Eligible registration rate: 3 registered / 4 eligible = 0.75
DO $$
DECLARE
  rate NUMERIC;
BEGIN
  SELECT
    SUM(CASE WHEN g.pcah_reg_date IS NOT NULL THEN 1 ELSE 0 END)::NUMERIC
    / NULLIF(SUM(CASE WHEN a.pcah_eligible THEN 1 ELSE 0 END), 0)
  INTO rate
  FROM accounts a
  LEFT JOIN pcah_reg g ON a.account_id = g.account_id;
  IF rate IS DISTINCT FROM 0.75 THEN
    RAISE EXCEPTION 'pcah rate expected 0.75 got %', rate;
  END IF;
END $$;

-- Median latency for 2018 registrations: days 9,16,19 → median 16
DO $$
DECLARE
  med NUMERIC;
BEGIN
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (
    ORDER BY (g.pcah_reg_date - a.account_created_date)
  ) INTO med
  FROM accounts a
  JOIN pcah_reg g ON a.account_id = g.account_id
  WHERE EXTRACT(YEAR FROM g.pcah_reg_date) = 2018;
  IF med IS DISTINCT FROM 16 THEN
    RAISE EXCEPTION 'median latency expected 16 got %', med;
  END IF;
END $$;

SELECT 'healthcare_smoke OK' AS status;
