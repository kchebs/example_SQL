-- Ecommerce smoke assertions (Postgres-portable).
\set ON_ERROR_STOP on

-- Successful non-upsell line counts by store/date for order status 150
CREATE TEMP TABLE ecom_ship_actual AS
SELECT
  CAST(fo.datetime_shipped AS DATE) AS date_shipped,
  dpt.product_type_label,
  ds.store_label,
  COUNT(fol.order_line_id) AS items_sold
FROM fact_order_line fol
JOIN fact_order fo ON fol.order_id = fo.order_id
JOIN dim_store ds ON fo.store_id = ds.store_id
JOIN dim_product_type dpt ON fol.product_type_id = dpt.product_type_id
WHERE fol.statuscode = 'Item Successful'
  AND dpt.product_type_label <> 'Upsell Item'
  AND fo.statuscode = 150
GROUP BY ds.store_label, CAST(fo.datetime_shipped AS DATE), dpt.product_type_label;

DO $$
DECLARE
  nyc_meal INTEGER;
BEGIN
  SELECT items_sold INTO nyc_meal
  FROM ecom_ship_actual
  WHERE store_label = 'NYC'
    AND product_type_label = 'Meal Kit'
    AND date_shipped = DATE '2022-06-15';
  IF nyc_meal IS DISTINCT FROM 4 THEN
    RAISE EXCEPTION 'ecommerce ship count expected 4 got %', nyc_meal;
  END IF;
END $$;

-- Cash refund totals for credit-billing orders
CREATE TEMP TABLE ecom_refund_actual AS
SELECT
  fo.order_id,
  SUM(CASE WHEN fr.total_refund IS NOT NULL THEN fr.total_refund ELSE 0 END) AS refund
FROM fact_refund fr
JOIN fact_order fo ON fr.order_id = fo.order_id
JOIN dim_order_type dot ON fo.order_type_id = dot.order_type_id
JOIN dim_refund_type drt ON fr.refund_type_id = drt.refund_type_id
WHERE fr.statuscode = 100
  AND drt.refund_type_label = 'Cash Refund'
  AND dot.order_type_label = 'Credit Billing'
GROUP BY fo.order_id;

DO $$
DECLARE
  r100 NUMERIC;
BEGIN
  SELECT refund INTO r100 FROM ecom_refund_actual WHERE order_id = 100;
  IF r100 IS DISTINCT FROM 12.50 THEN
    RAISE EXCEPTION 'ecommerce refund expected 12.50 got %', r100;
  END IF;
  IF EXISTS (SELECT 1 FROM ecom_refund_actual WHERE order_id = 101) THEN
    RAISE EXCEPTION 'order 101 should not appear (store credit only)';
  END IF;
END $$;

SELECT 'ecommerce_smoke OK' AS status;
