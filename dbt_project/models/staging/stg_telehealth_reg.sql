select
  account_id,
  telehealth_reg_date
from {{ source('healthcare', 'telehealth_reg') }}
