-- Data-quality assertions (dbt-style unique / not_null / relationships /
-- accepted_values / expression tests) on source tables for all smoke domains.
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Sports
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  n INTEGER;
BEGIN
  -- unique + not_null on PKs
  SELECT COUNT(*) - COUNT(DISTINCT PersonID) INTO n FROM Person;
  IF n <> 0 OR EXISTS (SELECT 1 FROM Person WHERE PersonID IS NULL) THEN
    RAISE EXCEPTION 'DQ Person PK failed';
  END IF;

  SELECT COUNT(*) - COUNT(DISTINCT SportID) INTO n FROM Sport;
  IF n <> 0 OR EXISTS (SELECT 1 FROM Sport WHERE SportID IS NULL OR SportType IS NULL) THEN
    RAISE EXCEPTION 'DQ Sport PK/SportType failed';
  END IF;

  -- relationships: History → Person, Sport
  IF EXISTS (
    SELECT 1 FROM History h
    LEFT JOIN Person p ON h.PersonID = p.PersonID
    WHERE p.PersonID IS NULL
  ) THEN
    RAISE EXCEPTION 'DQ History orphan PersonID';
  END IF;

  IF EXISTS (
    SELECT 1 FROM History h
    LEFT JOIN Sport s ON h.SportID = s.SportID
    WHERE s.SportID IS NULL
  ) THEN
    RAISE EXCEPTION 'DQ History orphan SportID';
  END IF;

  -- expression: non-negative scores
  IF EXISTS (SELECT 1 FROM History WHERE Score < 0) THEN
    RAISE EXCEPTION 'DQ History.Score < 0';
  END IF;

  -- row-count floor (seed contract)
  SELECT COUNT(*) INTO n FROM Person;
  IF n < 3 THEN RAISE EXCEPTION 'DQ Person row count %', n; END IF;
  SELECT COUNT(*) INTO n FROM Sport;
  IF n < 4 THEN RAISE EXCEPTION 'DQ Sport row count %', n; END IF;
  SELECT COUNT(*) INTO n FROM History;
  IF n < 5 THEN RAISE EXCEPTION 'DQ History row count %', n; END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Ecommerce
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  n INTEGER;
BEGIN
  SELECT COUNT(*) - COUNT(DISTINCT store_id) INTO n FROM dim_store;
  IF n <> 0 THEN RAISE EXCEPTION 'DQ dim_store unique failed'; END IF;
  SELECT COUNT(*) - COUNT(DISTINCT product_type_id) INTO n FROM dim_product_type;
  IF n <> 0 THEN RAISE EXCEPTION 'DQ dim_product_type unique failed'; END IF;
  SELECT COUNT(*) - COUNT(DISTINCT order_id) INTO n FROM fact_order;
  IF n <> 0 THEN RAISE EXCEPTION 'DQ fact_order unique failed'; END IF;
  SELECT COUNT(*) - COUNT(DISTINCT order_line_id) INTO n FROM fact_order_line;
  IF n <> 0 THEN RAISE EXCEPTION 'DQ fact_order_line unique failed'; END IF;
  SELECT COUNT(*) - COUNT(DISTINCT refund_id) INTO n FROM fact_refund;
  IF n <> 0 THEN RAISE EXCEPTION 'DQ fact_refund unique failed'; END IF;

  -- relationships
  IF EXISTS (
    SELECT 1 FROM fact_order fo
    LEFT JOIN dim_store ds ON fo.store_id = ds.store_id
    WHERE ds.store_id IS NULL
  ) THEN
    RAISE EXCEPTION 'DQ fact_order orphan store_id';
  END IF;

  IF EXISTS (
    SELECT 1 FROM fact_order_line fol
    LEFT JOIN fact_order fo ON fol.order_id = fo.order_id
    WHERE fo.order_id IS NULL
  ) THEN
    RAISE EXCEPTION 'DQ fact_order_line orphan order_id';
  END IF;

  IF EXISTS (
    SELECT 1 FROM fact_refund fr
    LEFT JOIN fact_order fo ON fr.order_id = fo.order_id
    WHERE fo.order_id IS NULL
  ) THEN
    RAISE EXCEPTION 'DQ fact_refund orphan order_id';
  END IF;

  -- accepted_values
  IF EXISTS (
    SELECT 1 FROM dim_product_type
    WHERE product_type_label NOT IN ('Meal Kit', 'Upsell Item')
  ) THEN
    RAISE EXCEPTION 'DQ unexpected product_type_label';
  END IF;

  IF EXISTS (
    SELECT 1 FROM dim_refund_type
    WHERE refund_type_label NOT IN ('Cash Refund', 'Store Credit')
  ) THEN
    RAISE EXCEPTION 'DQ unexpected refund_type_label';
  END IF;

  IF EXISTS (
    SELECT 1 FROM fact_order_line
    WHERE statuscode NOT IN ('Item Successful')
  ) THEN
    RAISE EXCEPTION 'DQ unexpected order_line statuscode';
  END IF;

  -- expression: refunds non-negative when present
  IF EXISTS (SELECT 1 FROM fact_refund WHERE total_refund IS NOT NULL AND total_refund < 0) THEN
    RAISE EXCEPTION 'DQ negative total_refund';
  END IF;

  SELECT COUNT(*) INTO n FROM fact_order;
  IF n < 3 THEN RAISE EXCEPTION 'DQ fact_order row count %', n; END IF;
  SELECT COUNT(*) INTO n FROM fact_order_line;
  IF n < 6 THEN RAISE EXCEPTION 'DQ fact_order_line row count %', n; END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Healthcare
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  n INTEGER;
BEGIN
  SELECT COUNT(*) - COUNT(DISTINCT account_id) INTO n FROM accounts;
  IF n <> 0 OR EXISTS (SELECT 1 FROM accounts WHERE account_id IS NULL OR account_created_date IS NULL) THEN
    RAISE EXCEPTION 'DQ accounts PK/not_null failed';
  END IF;

  SELECT COUNT(*) - COUNT(DISTINCT account_id) INTO n FROM telehealth_reg;
  IF n <> 0 THEN RAISE EXCEPTION 'DQ telehealth_reg unique failed'; END IF;

  -- relationships: telehealth_reg → accounts
  IF EXISTS (
    SELECT 1 FROM telehealth_reg g
    LEFT JOIN accounts a ON g.account_id = a.account_id
    WHERE a.account_id IS NULL
  ) THEN
    RAISE EXCEPTION 'DQ telehealth_reg orphan account_id';
  END IF;

  -- expression: registration on or after account creation
  IF EXISTS (
    SELECT 1
    FROM telehealth_reg g
    JOIN accounts a ON g.account_id = a.account_id
    WHERE g.telehealth_reg_date < a.account_created_date
  ) THEN
    RAISE EXCEPTION 'DQ telehealth_reg_date before account_created_date';
  END IF;

  SELECT COUNT(*) INTO n FROM accounts;
  IF n < 5 THEN RAISE EXCEPTION 'DQ accounts row count %', n; END IF;
  SELECT COUNT(*) INTO n FROM telehealth_reg;
  IF n < 3 THEN RAISE EXCEPTION 'DQ telehealth_reg row count %', n; END IF;
END $$;

SELECT 'data_quality_smoke OK' AS status;
