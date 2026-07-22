Table Structure:
CREATE TABLE listener_ad_impression_conversion (
    listener_id bigint
    , channel string
    , feature_code string
   , store string
)
PARTITIONED BY (day STRING)
 
Details:
1. The table tracks every ad impression a listener is served by channel and feature_code and tracks a conversion to a trial start with the store
2. If the store is NULL then the impression did not convert the listener into a trial
2. The table has data between 2017-01-01 and 2017-12-31 (inclusive).
4. All distinct combinations of channel, stores and feature codes in the table are shown below
 
Questions:
1. Please provide the query that returns the count of impressions across channels and feature codes by month.
- Note: one listener can receive multiple impressions within a day and across days (ex: listener_id = 239913), but can only start a trial for a specific feature code and day once.
 
SELECT 
MONTH(CAST(day as datetime)) month,
feature_code,
channel,
COUNT(*) impression_count
FROM listener_ad_impression_conversion
GROUP BY MONTH(CAST(day as datetime)),
feature_code,
channel

2. Please provide the query that returns the count of trial starts by channel, billing platform and day.
- Note: billing platform is different than store and the mapping from store to billing platform is defined below:
Store
Billing Platform
Apple - Apple
Google - Google
Paymentech - Direct
Paypal - Direct
 

SELECT
channel,
CASE WHEN lower(store) IN ('apple','google') THEN store 
WHEN lower(store) IN ('paymentech','paypal') THEN 'Direct' END billing_platform,
day,
sum(case when store is not null then 1 else 0 end) trial_start_counts
FROM listener_ad_impression_conversion
GROUP BY channel, day, CASE WHEN lower(store) IN ('apple','google') then store 
WHEN lower(store) IN ('paymentech','paypal') THEN 'Direct' END


3. Please provide the query that returns the conversion rate across for each channel by month
- Note: conversion rate = trial starts/impressions

SELECT
channel,
MONTH(CAST(day as datetime)) month,
sum(case when store is not null then 1 else 0 end)/COUNT(*) conversion_rate
FROM listener_ad_impression_conversion
GROUP BY channel, MONTH(CAST(day as datetime))

 
Note:
Please comment and format your code where necessary
 
Sample output from the listener_ad_impression_conversion table:
listener_id channel feature_code store day 
239913 house_ad streaming_plus NULL 2016-01-01
234234 house_ad streaming_premium NULL 2016-01-01
32423 smart_conversion streaming_plus google 2016-01-01
34235 paid_ad premium_family_plan NULL 2016-01-01
95438 paid_ad streaming_premium NULL 2016-01-01
43584 smart_conversion streaming_plus paymentech 2016-01-02
54385438 house_ad streaming_plus paypal 2016-01-02
5943 paid_ad streaming_plus NULL 2016-01-02
9483 smart_conversion streaming_premium paypal 2016-01-02
239913 house_ad streaming_plus apple 2016-01-03
2957 smart_conversion premium_family_plan google 2016-01-03
8483 smart_conversion streaming_plus NULL 2016-01-03
38391 paid_ad streaming_plus paymentech 2016-01-03
82832 house_ad streaming_premium apple 2016-01-03