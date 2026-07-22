-- Ecommerce dimensional schema (Postgres) for docker smoke tests.
-- Simplified subset aligned with sql/ecommerce_order_analytics.sql concepts.

CREATE TABLE dim_store (
    store_id INTEGER PRIMARY KEY,
    store_label TEXT NOT NULL
);

CREATE TABLE dim_product_type (
    product_type_id INTEGER PRIMARY KEY,
    product_type_label TEXT NOT NULL
);

CREATE TABLE dim_order_type (
    order_type_id INTEGER PRIMARY KEY,
    order_type_label TEXT NOT NULL
);

CREATE TABLE dim_refund_type (
    refund_type_id INTEGER PRIMARY KEY,
    refund_type_label TEXT NOT NULL
);

CREATE TABLE fact_order (
    order_id INTEGER PRIMARY KEY,
    store_id INTEGER NOT NULL REFERENCES dim_store (store_id),
    order_type_id INTEGER NOT NULL REFERENCES dim_order_type (order_type_id),
    statuscode INTEGER NOT NULL,
    datetime_shipped TIMESTAMP NOT NULL
);

CREATE TABLE fact_order_line (
    order_line_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES fact_order (order_id),
    product_id INTEGER NOT NULL,
    product_type_id INTEGER NOT NULL REFERENCES dim_product_type (product_type_id),
    statuscode TEXT NOT NULL
);

CREATE TABLE fact_refund (
    refund_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES fact_order (order_id),
    refund_type_id INTEGER NOT NULL REFERENCES dim_refund_type (refund_type_id),
    statuscode INTEGER NOT NULL,
    total_refund NUMERIC(10, 2)
);
