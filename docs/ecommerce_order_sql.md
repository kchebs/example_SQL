# Ecommerce Order Analytics SQL

Personal SQL examples for meal-kit / subscription ecommerce fact tables: successful item counts, monthly mix, cash refunds, set unions, and same-month-last-year order counts.

Schemas are assumed from a dimensional model (`fact_order`, `fact_order_line`, `dim_*`, `dim_date`). Temp-table names match the prompts.

Executable queries: [`../sql/ecommerce_order_analytics.sql`](../sql/ecommerce_order_analytics.sql).

## 1. High-volume successful shipments

Count items sold by `store_label`, `date_shipped`, and `product_type_label` where the group has **> 500** items. Require successful order and line status; exclude upsell items.

```sql
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
```

## 2. Monthly share of items by product type

Assume Q1 results live in `#products_sold` / `products_sold`.

```sql
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
```

## 3. Cash refund amounts for credit-billing orders

Multiple refunds per order possible; show `0` when no refund. Successful cash refunds only.

```sql
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
```

## 4. Union of order ID lists (no duplicates)

```sql
SELECT order_id FROM temp_order1
UNION DISTINCT
SELECT order_id FROM temp_order2;
```

## 5. Orders per month vs same month last year

`orders_by_month` has daily order counts; `dim_date` maps each day to `month_date`.

```sql
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
```
