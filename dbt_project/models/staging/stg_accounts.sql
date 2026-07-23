select
  account_id,
  account_created_date,
  telehealth_eligible
from {{ source('healthcare', 'accounts') }}
