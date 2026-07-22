-- Mobile game cohort, monetization, and ad creative SQL examples
-- Companion write-up: docs/mobile_game_marketing_analytics.md

-- Cohort size
SELECT
  platform,
  install_date,
  COUNT(DISTINCT DeviceID) AS cohort_size
FROM (
  SELECT deviceid,
         MIN(DATE(login_time)) AS install_date,
         platform
  FROM player_login
  GROUP BY deviceid, platform
) sub
GROUP BY platform, install_date;

-- D1 / D7 / D30 retention
SELECT
  Platform,
  install_date,
  COUNT(DISTINCT CASE
    WHEN DATEDIFF(DAY, install_date, DATE(login_time)) = 1 THEN DeviceID END)
    / COUNT(DISTINCT DeviceID) AS D1,
  COUNT(DISTINCT CASE
    WHEN DATEDIFF(DAY, install_date, DATE(login_time)) = 7 THEN DeviceID END)
    / COUNT(DISTINCT DeviceID) AS D7,
  COUNT(DISTINCT CASE
    WHEN DATEDIFF(DAY, install_date, DATE(login_time)) = 30 THEN DeviceID END)
    / COUNT(DISTINCT DeviceID) AS D30
FROM Player_login l
JOIN (
  SELECT deviceid,
         MIN(DATE(login_time)) AS install_date,
         platform
  FROM player_login
  GROUP BY deviceid, platform
) sub
  ON sub.deviceid = l.deviceid AND sub.platform = l.platform
GROUP BY platform, install_date;

-- Cumulative purchase rate
SELECT
  Platform,
  Install_Date,
  COUNT(DISTINCT CASE
    WHEN DATEDIFF(DAY, Install_Date, DATE(Purchase_Time)) <= 1 THEN DeviceID END)
    / COUNT(DISTINCT DeviceID) AS D1_CONV,
  COUNT(DISTINCT CASE
    WHEN DATEDIFF(DAY, Install_Date, DATE(Purchase_Time)) <= 7 THEN DeviceID END)
    / COUNT(DISTINCT DeviceID) AS D7_CONV,
  COUNT(DISTINCT CASE
    WHEN DATEDIFF(DAY, Install_Date, DATE(Purchase_Time)) <= 30 THEN DeviceID END)
    / COUNT(DISTINCT DeviceID) AS D30_CONV
FROM (
  SELECT deviceid,
         MIN(DATE(login_time)) AS install_date,
         platform
  FROM player_login
  GROUP BY deviceid, platform
) sub
LEFT JOIN Player_Purchases p ON sub.DeviceID = p.DeviceID
GROUP BY Platform, Install_Date;

-- ARPU
SELECT
  Platform,
  Install_Date,
  COALESCE(SUM(D1_purchases) / COUNT(DISTINCT DeviceID), 0) AS ARPU_D1,
  COALESCE(SUM(D7_purchases) / COUNT(DISTINCT DeviceID), 0) AS ARPU_D7,
  COALESCE(SUM(D30_purchases) / COUNT(DISTINCT DeviceID), 0) AS ARPU_D30
FROM (
  SELECT deviceid,
         MIN(DATE(login_time)) AS install_date,
         platform
  FROM player_login
  GROUP BY deviceid, platform
) sub
LEFT JOIN (
  SELECT
    p.deviceID,
    sub2.install_date,
    SUM(CASE WHEN DATEDIFF(DAY, sub2.install_date, DATE(Purchase_Time)) <= 1
             THEN Purchase_Value END) AS D1_purchases,
    SUM(CASE WHEN DATEDIFF(DAY, sub2.install_date, DATE(Purchase_Time)) <= 7
             THEN Purchase_Value END) AS D7_purchases,
    SUM(CASE WHEN DATEDIFF(DAY, sub2.install_date, DATE(Purchase_Time)) <= 30
             THEN Purchase_Value END) AS D30_purchases
  FROM Player_Purchases p
  JOIN (
    SELECT deviceid, MIN(DATE(login_time)) AS install_date
    FROM player_login
    GROUP BY deviceid
  ) sub2 ON p.DeviceID = sub2.deviceid
  GROUP BY p.deviceID, sub2.install_date
) pay ON sub.DeviceID = pay.DeviceID
GROUP BY Platform, Install_Date;

-- ARPPU (paying users only)
SELECT
  Platform,
  Install_Date,
  COALESCE(SUM(D1_purchases) / NULLIF(COUNT(DISTINCT CASE WHEN D1_purchases > 0 THEN purchaserID END), 0), 0) AS ARPPU_D1,
  COALESCE(SUM(D7_purchases) / NULLIF(COUNT(DISTINCT CASE WHEN D7_purchases > 0 THEN purchaserID END), 0), 0) AS ARPPU_D7,
  COALESCE(SUM(D30_purchases) / NULLIF(COUNT(DISTINCT CASE WHEN D30_purchases > 0 THEN purchaserID END), 0), 0) AS ARPPU_D30
FROM (
  SELECT deviceid,
         MIN(DATE(login_time)) AS install_date,
         platform
  FROM player_login
  GROUP BY deviceid, platform
) sub
INNER JOIN (
  SELECT
    p.deviceID AS purchaserID,
    sub2.install_date,
    SUM(CASE WHEN DATEDIFF(DAY, sub2.install_date, DATE(Purchase_Time)) <= 1
             THEN Purchase_Value END) AS D1_purchases,
    SUM(CASE WHEN DATEDIFF(DAY, sub2.install_date, DATE(Purchase_Time)) <= 7
             THEN Purchase_Value END) AS D7_purchases,
    SUM(CASE WHEN DATEDIFF(DAY, sub2.install_date, DATE(Purchase_Time)) <= 30
             THEN Purchase_Value END) AS D30_purchases
  FROM Player_Purchases p
  JOIN (
    SELECT deviceid, MIN(DATE(login_time)) AS install_date
    FROM player_login
    GROUP BY deviceid
  ) sub2 ON p.DeviceID = sub2.deviceid
  GROUP BY p.deviceID, sub2.install_date
) pay ON sub.DeviceID = pay.purchaserID
GROUP BY Platform, Install_Date;

-- Top 5 creatives by CTR per Creative_Type (last 30 days, ~90% CI)
WITH ad_clicks AS (
  SELECT CreativeID, COUNT(DISTINCT DeviceID) AS clicks
  FROM Creative_Clicks
  WHERE Click_Time >= DATEADD(day, -30, GETDATE())
  GROUP BY CreativeID
),
ad_impressions AS (
  SELECT CreativeID, Creative_Type, COUNT(DISTINCT DeviceID) AS impressions
  FROM Creative_Impressions
  WHERE Impression_View_Time >= DATEADD(day, -30, GETDATE())
  GROUP BY CreativeID, Creative_Type
),
ad_ctr AS (
  SELECT
    im.CreativeID,
    im.Creative_Type,
    ci.clicks,
    im.impressions,
    1.0 * ci.clicks / im.impressions AS CTR,
    ROUND(1.96 * SQRT(1.0 * ci.clicks / im.impressions * (1 - 1.0 * ci.clicks / im.impressions) / im.impressions), 4) AS CI_90,
    ROW_NUMBER() OVER (PARTITION BY im.Creative_Type ORDER BY 1.0 * ci.clicks / im.impressions DESC) AS rn
  FROM ad_clicks ci
  JOIN ad_impressions im ON ci.CreativeID = im.CreativeID
)
SELECT
  Creative_Type,
  CreativeID,
  CTR,
  CTR - CI_90 AS CI_Lower,
  CTR + CI_90 AS CI_Upper
FROM ad_ctr
WHERE rn <= 5
ORDER BY Creative_Type, CTR DESC;

-- Top 5 creatives by IPM (installs per 1000 impressions)
WITH ad_impressions AS (
  SELECT
    CreativeID,
    Creative_Type,
    COUNT(DISTINCT deviceID) AS impressions
  FROM Creative_Impressions
  WHERE Impression_View_Time >= DATEADD(day, -30, GETDATE())
  GROUP BY CreativeID, Creative_Type
  HAVING COUNT(DISTINCT deviceID) > 0
),
ad_installs AS (
  SELECT
    CreativeID,
    COUNT(DISTINCT deviceID) AS installs
  FROM Install_Table
  WHERE Install_Time >= DATEADD(day, -30, GETDATE())
  GROUP BY CreativeID
),
ad_ipm AS (
  SELECT
    ai.Creative_Type,
    ai.CreativeID,
    ai.impressions,
    inst.installs,
    1.0 * inst.installs / ai.impressions * 1000 AS IPM,
    ROUND(
      1.96 * SQRT(1.0 * inst.installs / ai.impressions * (1 - 1.0 * inst.installs / ai.impressions) / ai.impressions) * 1000,
      4
    ) AS CI_90,
    ROW_NUMBER() OVER (PARTITION BY ai.Creative_Type ORDER BY 1.0 * inst.installs / ai.impressions * 1000 DESC) AS rn
  FROM ad_impressions ai
  JOIN ad_installs inst ON ai.CreativeID = inst.CreativeID
)
SELECT
  Creative_Type,
  CreativeID,
  IPM,
  IPM - CI_90 AS CI_Lower,
  IPM + CI_90 AS CI_Upper
FROM ad_ipm
WHERE rn <= 5
ORDER BY Creative_Type, IPM DESC;

-- Organic installs (no attributed creative)
SELECT COUNT(DISTINCT it.DeviceID) AS OrganicInstalls
FROM Install_Table it
WHERE it.Install_Time >= DATEADD(day, -30, GETDATE())
  AND it.CreativeID IS NULL;
