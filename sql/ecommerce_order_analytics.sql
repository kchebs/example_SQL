-- Ecommerce / meal-kit order analytics SQL examples
-- Companion write-up: docs/ecommerce_order_sql.md

-- Q1: successful non-upsell item counts > 500 by store, ship date, product type
SELECT
  CAST(Datetime_shipped AS DATE) AS date_shipped,
  Product_type_label,
  Store_label,
  SUM(items_in_order) AS items_sold
FROM (
  SELECT
    fact_order_line.order_id,
    COUNT(product_id) AS items_in_order,
    Product_type_label
  FROM fact_order_line
  LEFT JOIN dim_order_line_statuscode
    ON fact_order_line.statuscode = dim_order_line_statuscode.statuscode
  LEFT JOIN dim_product_type
    ON dim_product_type.product_type_id = fact_order_line.product_type_id
  WHERE statuscode = 'Item Successful'
    AND product_type_label != 'Upsell Item'
  GROUP BY fact_order_line.order_id, Product_type_label
) a
LEFT JOIN fact_order ON a.order_id = fact_order.order_id
LEFT JOIN dim_store ON fact_order.store_id = dim_store.store_id
WHERE fact_order.statuscode = 150
GROUP BY store_label, date_shipped, product_type_label
HAVING items_sold > 500;

-- Q2: monthly item share by product type (from products_sold temp)
SELECT
  Product_type_label,
  Truncated_month_year,
  SUM(Items_sold_in_month) / SUM(total_items) AS percent_items
FROM (
  SELECT
    SUM(items_sold) AS items_sold_in_month,
    DATETIME_TRUNC(Datetime_shipped, MONTH) AS truncated_month_year,
    Product_type_label,
    SUM(items_sold) OVER (PARTITION BY product_type_label) AS total_items
  FROM products_sold
  GROUP BY product_type_label, truncated_month_year
) monthly
GROUP BY product_type_label, truncated_month_year;

-- Q3: cash refund totals for credit-billing orders
SELECT
  Order_id,
  SUM(CASE WHEN total_refund IS NOT NULL THEN total_refund ELSE 0 END) AS refund
FROM fact_refund
LEFT JOIN fact_order ON fact_refund.order_id = fact_order.order_id
LEFT JOIN dim_order_type ON dim_order_type.order_type_id = fact_order.order_type_id
LEFT JOIN dim_refund_type ON dim_refund_type.refund_type_id = fact_refund.refund_type_id
WHERE fact_refund.statuscode = 100
  AND refund_type_label = 'Cash Refund'
  AND order_type_label = 'Credit Billing'
GROUP BY order_id;

-- Q4: distinct order IDs across two temp lists
SELECT order_id FROM temp_order1
UNION DISTINCT
SELECT order_id FROM temp_order2;

-- Q5: monthly orders vs same month last year
SELECT
  current_year.store_name AS store,
  current_year.customer_id,
  dim_date.month_date,
  SUM(CASE WHEN current_year.order_count IS NOT NULL THEN current_year.order_count ELSE 0 END) AS order_count,
  MAX(last_year.order_count) AS order_count_same_month_last_year
FROM orders_by_month AS current_year
LEFT JOIN dim_date ON current_year.date = dim_date.date
LEFT JOIN (
  SELECT
    SUM(CASE WHEN order_count IS NOT NULL THEN order_count ELSE 0 END) AS order_count,
    month_date,
    customer_id,
    store_name
  FROM orders_by_month
  LEFT JOIN dim_date ON dim_date.date = orders_by_month.date
  GROUP BY month_date, customer_id, store_name
) AS last_year
  ON last_year.month_date = DATE_SUB(dim_date.month_date, INTERVAL 365 DAY)
 AND last_year.store_name = current_year.store_name
 AND current_year.customer_id = last_year.customer_id
GROUP BY current_year.store_name, current_year.customer_id, dim_date.month_date;
