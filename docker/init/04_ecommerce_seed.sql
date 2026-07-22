-- Deterministic ecommerce seed for smoke assertions.
INSERT INTO dim_store (store_id, store_label) VALUES
    (1, 'NYC'),
    (2, 'SF');

INSERT INTO dim_product_type (product_type_id, product_type_label) VALUES
    (1, 'Meal Kit'),
    (2, 'Upsell Item');

INSERT INTO dim_order_type (order_type_id, order_type_label) VALUES
    (1, 'Credit Billing'),
    (2, 'Prepaid');

INSERT INTO dim_refund_type (refund_type_id, refund_type_label) VALUES
    (1, 'Cash Refund'),
    (2, 'Store Credit');

-- Order 100: successful NYC meal-kit shipment with 3 successful lines
INSERT INTO fact_order (order_id, store_id, order_type_id, statuscode, datetime_shipped) VALUES
    (100, 1, 1, 150, '2022-06-15 12:00:00'),
    (101, 1, 1, 150, '2022-06-15 13:00:00'),
    (102, 2, 2, 150, '2022-06-16 10:00:00');

INSERT INTO fact_order_line (order_line_id, order_id, product_id, product_type_id, statuscode) VALUES
    (1, 100, 10, 1, 'Item Successful'),
    (2, 100, 11, 1, 'Item Successful'),
    (3, 100, 12, 1, 'Item Successful'),
    (4, 101, 13, 1, 'Item Successful'),
    (5, 101, 14, 2, 'Item Successful'), -- upsell excluded from meal-kit counts
    (6, 102, 15, 1, 'Item Successful');

-- Refunds: order 100 has cash refund 12.50; order 101 has store credit only
INSERT INTO fact_refund (refund_id, order_id, refund_type_id, statuscode, total_refund) VALUES
    (1, 100, 1, 100, 12.50),
    (2, 101, 2, 100, 5.00);
