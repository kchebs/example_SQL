-- Healthcare scheduling / telehealth registration SQL examples
-- Companion write-up: docs/DETAILED_SQL_WALKTHROUGH.md (Healthcare section)
-- Company names genericized as Healthcare Technology Company / Telehealth

-- Q1a: accounts created in the last year
SELECT COUNT(*)
FROM accounts
WHERE account_created_date >= DATEADD(year, -1, GETDATE());

-- Q1b: share of eligible users who register for Telehealth
SELECT
  SUM(CASE WHEN telehealth_reg_date IS NOT NULL THEN 1 ELSE 0 END)
  / SUM(CASE WHEN telehealth_eligible IS TRUE THEN 1 ELSE 0 END) AS prp_reg_oo_elig
FROM accounts a
LEFT JOIN telehealth_reg g ON a.account_id = g.account_id;

-- Q1c: monthly Telehealth registration rate and MoM change (2018)
SELECT
  date_trunc('month', account_created_date) AS date,
  SUM(CASE WHEN telehealth_eligible = True AND telehealth_reg_date IS NOT NULL THEN 1 ELSE 0 END)
    / SUM(CASE WHEN telehealth_eligible = True THEN 1 ELSE 0 END) AS months_rate,
  100 * (
    SUM(CASE WHEN telehealth_eligible = True AND telehealth_reg_date IS NOT NULL THEN 1 ELSE 0 END)
      / SUM(CASE WHEN telehealth_eligible = True THEN 1 ELSE 0 END)
    - LAG(
        SUM(CASE WHEN telehealth_eligible = True AND telehealth_reg_date IS NOT NULL THEN 1 ELSE 0 END)
          / SUM(CASE WHEN telehealth_eligible = True THEN 1 ELSE 0 END)
      ) OVER (ORDER BY date_trunc('month', account_created_date))
  ) / LAG(
        SUM(CASE WHEN telehealth_eligible = True AND telehealth_reg_date IS NOT NULL THEN 1 ELSE 0 END)
          / SUM(CASE WHEN telehealth_eligible = True THEN 1 ELSE 0 END)
      ) OVER (ORDER BY date_trunc('month', account_created_date))
  || '%' AS MoM_change
FROM accounts ac
LEFT JOIN telehealth_reg gr ON ac.account_id = gr.account_id
WHERE date_part('year', account_created_date) = 2018
GROUP BY date_trunc('month', account_created_date)
ORDER BY date_trunc('month', account_created_date) ASC;

-- Q1d: median latency account -> Telehealth registration (2018 signups)
SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (
    ORDER BY DATEDIFF(day, account_created_date, telehealth_reg_date)
  ) AS median_latency
FROM accounts ac
LEFT JOIN telehealth_reg gr ON ac.account_id = gr.account_id
WHERE date_part('year', telehealth_reg_date) = 2018;

-- Q2a: available GPs vs appointment requests per slot
SELECT
  slots,
  COUNT(DISTINCT CASE WHEN request_appt_start IS NOT NULL THEN patient_id END) AS num_of_requests,
  COUNT(DISTINCT CASE
    WHEN slots >= book_slot_start AND slots < booked_slot_end THEN gp_id
  END) AS num_of_avail_gps
FROM slots s
LEFT JOIN requested_appointment_slots ra ON s.slots = ra.requested_appt_start
CROSS JOIN booked_gp_slots
GROUP BY slots;
