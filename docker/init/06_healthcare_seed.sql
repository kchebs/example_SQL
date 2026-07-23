-- Deterministic healthcare seed for smoke assertions.
-- Fixed "as-of" date used in tests: 2019-01-01 (see healthcare_smoke.sql).
INSERT INTO accounts (account_id, account_created_date, telehealth_eligible) VALUES
    (1, '2018-03-01', TRUE),
    (2, '2018-06-15', TRUE),
    (3, '2018-09-01', TRUE),
    (4, '2017-01-01', TRUE),   -- created >1 year before as-of when as-of=2019-01-01
    (5, '2018-11-01', FALSE);  -- ineligible

INSERT INTO telehealth_reg (account_id, telehealth_reg_date) VALUES
    (1, '2018-03-10'),  -- 9 day latency
    (2, '2018-07-01'),  -- 16 day latency
    (3, '2018-09-20');  -- 19 day latency
-- account 4 eligible but never registered; account 5 ineligible
