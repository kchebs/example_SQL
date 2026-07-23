-- Telehealth registration funnel KPIs (as-of 2019-01-01 style snapshot)
with accounts as (
  select * from {{ ref('stg_accounts') }}
),
regs as (
  select * from {{ ref('stg_telehealth_reg') }}
)
select
  (
    sum(case when r.telehealth_reg_date is not null then 1 else 0 end)::numeric
    / nullif(sum(case when a.telehealth_eligible then 1 else 0 end), 0)
  ) as eligible_registration_rate,
  percentile_cont(0.5) within group (
    order by (r.telehealth_reg_date - a.account_created_date)
  ) filter (
    where extract(year from r.telehealth_reg_date) = 2018
  ) as median_reg_latency_days_2018
from accounts a
left join regs r on a.account_id = r.account_id
