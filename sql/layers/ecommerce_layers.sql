-- dbt-style layer examples for the ecommerce domain (reference only; not loaded by docker init).
-- See docs/dbt_style_layering.md

-- staging: order lines with dimension labels
-- stg_order_lines
SELECT
  fol.order_line_id,
  fol.order_id,
  fol.product_id,
  fol.statuscode AS line_status,
  dpt.product_type_label,
  fo.statuscode AS order_status,
  fo.datetime_shipped,
  ds.store_label,
  CAST(fo.datetime_shipped AS DATE) AS date_shipped
FROM fact_order_line fol
JOIN fact_order fo ON fol.order_id = fo.order_id
JOIN dim_store ds ON fo.store_id = ds.store_id
JOIN dim_product_type dpt ON fol.product_type_id = dpt.product_type_id;

-- intermediate: successful shipped non-upsell lines
-- int_shipped_successful_lines
SELECT *
FROM (
  SELECT
    fol.order_line_id,
    fol.order_id,
    dpt.product_type_label,
    ds.store_label,
    CAST(fo.datetime_shipped AS DATE) AS date_shipped
  FROM fact_order_line fol
  JOIN fact_order fo ON fol.order_id = fo.order_id
  JOIN dim_store ds ON fo.store_id = ds.store_id
  JOIN dim_product_type dpt ON fol.product_type_id = dpt.product_type_id
  WHERE fol.statuscode = 'Item Successful'
    AND dpt.product_type_label <> 'Upsell Item'
    AND fo.statuscode = 150
) shipped;

-- mart: items sold by store / ship date / product type
-- mart_items_sold_by_store_day
SELECT
  store_label,
  date_shipped,
  product_type_label,
  COUNT(order_line_id) AS items_sold
FROM (
  SELECT
    fol.order_line_id,
    dpt.product_type_label,
    ds.store_label,
    CAST(fo.datetime_shipped AS DATE) AS date_shipped
  FROM fact_order_line fol
  JOIN fact_order fo ON fol.order_id = fo.order_id
  JOIN dim_store ds ON fo.store_id = ds.store_id
  JOIN dim_product_type dpt ON fol.product_type_id = dpt.product_type_id
  WHERE fol.statuscode = 'Item Successful'
    AND dpt.product_type_label <> 'Upsell Item'
    AND fo.statuscode = 150
) x
GROUP BY store_label, date_shipped, product_type_label;

-- mart: cash refunds on credit-billing orders
-- mart_cash_refunds_credit_billing
SELECT
  fo.order_id,
  SUM(COALESCE(fr.total_refund, 0)) AS refund
FROM fact_refund fr
JOIN fact_order fo ON fr.order_id = fo.order_id
JOIN dim_order_type dot ON fo.order_type_id = dot.order_type_id
JOIN dim_refund_type drt ON fr.refund_type_id = drt.refund_type_id
WHERE fr.statuscode = 100
  AND drt.refund_type_label = 'Cash Refund'
  AND dot.order_type_label = 'Credit Billing'
GROUP BY fo.order_id;
