SELECT

CASE

WHEN SUBSTR(slicer, 3, 1) IN ("1") THEN "Test1"
WHEN SUBSTR(slicer, 3, 1) IN ("6") THEN "cs6"
WHEN SUBSTR(slicer, 3, 1) IN ("8") THEN "cs8"
WHEN SUBSTR(slicer, 3, 1) IN ("9") THEN "cs9"
WHEN SUBSTR(slicer, 3, 1) IN ("0") THEN "cs0"
WHEN SUBSTR(slicer, 3, 1) IN ("a") THEN "csa"
WHEN SUBSTR(slicer, 3, 1) IN ("b") THEN "csb"
WHEN SUBSTR(slicer, 3, 1) IN ("c") THEN "csc"
WHEN SUBSTR(slicer, 3, 1) IN ("d") THEN "csd"
WHEN SUBSTR(slicer, 3, 1) IN ("e") THEN "cse"
ELSE "other-tests"

END slice,
null ad_requests,
SUM(CASE WHEN event_type='filled' THEN 1 END) filled_ad_requests,
SUM(CASE WHEN event_type="start" THEN 1 END) all_impressions,
SUM(spend) all_spend,
SUM(earnings) all_earnings,
SUM(spend) - SUM(earnings) margin,
SUM(CASE WHEN event_type="attributed_install_direct" THEN 1
      WHEN event_type="attributed_install_indirect" THEN 1 END) installs,

avg(yo_probability) predicted_ir,
adserver_version,
CASE WHEN c.type IS NOT NULL THEN c.type WHEN c.type is NULL AND ipx_seat_id IS NOT NULL AND ipx_deal_id IS NOT NULL THEN "Private Marketplace" WHEN c.type is NULL AND ipx_seat_id IS NOT NULL AND ipx_deal_id IS NULL THEN "Open Exchange" END campaign_type,
e.pricing,
e.payment_method payment_method,
SUM(CASE WHEN event_type = "complete" THEN 1 ELSE 0 END) completed_view

FROM
  events e
  LEFT JOIN ad_campaigns c ON e.ad_campaign_id = c.id
WHERE
  _PARTITIONTIME >= TIMESTAMP("2018-11-16")
  AND _PARTITIONTIME <= TIMESTAMP("2018-11-17")
  AND e.served_time >= "2018-11-16 19:30:00"
  AND e.served_time <= "2018-11-17 20:00:00"
  AND adserver_version IN ("kind-lamb","astute-weasel")
GROUP BY
  slice,
  adserver_version,
  campaign_type,
  e.pricing,
  payment_method

  UNION ALL

SELECT

CASE

WHEN SUBSTR(slicer, 3, 1) IN ("1") THEN "Test1"
WHEN SUBSTR(slicer, 3, 1) IN ("6") THEN "cs6"
WHEN SUBSTR(slicer, 3, 1) IN ("8") THEN "cs8"
WHEN SUBSTR(slicer, 3, 1) IN ("9") THEN "cs9"
WHEN SUBSTR(slicer, 3, 1) IN ("0") THEN "cs0"
WHEN SUBSTR(slicer, 3, 1) IN ("a") THEN "csa"
WHEN SUBSTR(slicer, 3, 1) IN ("b") THEN "csb"
WHEN SUBSTR(slicer, 3, 1) IN ("c") THEN "csc"
WHEN SUBSTR(slicer, 3, 1) IN ("d") THEN "csd"
WHEN SUBSTR(slicer, 3, 1) IN ("e") THEN "cse"
ELSE "other-tests"

END slice,
SUM(CASE WHEN event_type='ad_request' THEN 1 END) ad_requests,
null filled_ad_requests,
null all_impressions,
null all_spend,
null all_earnings,
null margin,
null installs,

null predicted_ir,
adserver_version,
"" campaign_type,
ex.pricing,
ex.payment_method payment_method,
null completed_view

FROM
  events_extended ex
  LEFT JOIN ad_campaigns c ON ex.ad_campaign_id = c.id
WHERE
  _PARTITIONTIME >= TIMESTAMP("2018-11-16")
  AND _PARTITIONTIME <= TIMESTAMP("2018-11-17")
  AND ex.served_time >= "2018-11-16 19:30:00"
  AND ex.served_time <= "2018-11-17 20:00:00"
  AND adserver_version IN ("kind-lamb","astute-weasel")
GROUP BY
  slice,
  adserver_version,
  campaign_type,
  ex.pricing,
  payment_method
