# Mobile Game Marketing Analytics

Personal analytics write-up: install-cohort retention and monetization SQL, ad creative CTR/IPM ranking, organic installs, and UA media-mix reasoning.

Executable SQL: [`../sql/mobile_game_cohort_and_ads.sql`](../sql/mobile_game_cohort_and_ads.sql).

## Schemas

**Player activity**

| Table | Columns |
|-------|---------|
| `Player_Login` | `DeviceID`, `Login_Time`, `Platform` |
| `Player_Purchases` | `DeviceID`, `Purchase_Time`, `Purchase_Value` |

Notes: `DeviceID` is unique per player; login and purchase each leave a row.

Definitions:

- **Install cohort** — players who install on the same day for one platform
- **Day-0** — install date
- **Day-x retention** — % of the cohort that logs in on day x since install
- **Purchase rate** — % of users who purchase within a pool

**Marketing activity**

| Table | Columns |
|-------|---------|
| `Creative_Impressions` | `DeviceID`, `CreativeID`, `Creative_Type`, `Impression_View_Time` |
| `Creative_Clicks` | `DeviceID`, `Creative_ID` / `CreativeID`, `Click_Time` |
| `Install_Table` | `DeviceID`, `CreativeID`, `Install_Time` |

Organic install: install with `CreativeID IS NULL` (no attributed creative).

---

## 1. Cohort metrics by install date

### Cohort size

```sql
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
```

### Day-1 / 7 / 30 retention

```sql
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
```

### Cumulative purchase rate (D1 / D7 / D30)

```sql
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
```

### ARPU through D1 / D7 / D30

```sql
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
```

### ARPPU through D1 / D7 / D30

“Paying user” is defined here as anyone with a purchase record; period filters further restrict who enters each ARPPU denominator.

```sql
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
```

---

## 2. Creative performance (last 30 days)

### Top 5 creatives by CTR per ad type (with ~90% CI)

CTR is unique devices. See SQL file for the full CTE.

### Top 5 creatives by IPM (installs per 1000 impressions)

Same pattern with installs instead of clicks.

### Organic installs

```sql
SELECT COUNT(DISTINCT it.DeviceID) AS OrganicInstalls
FROM Install_Table it
WHERE it.Install_Time >= DATEADD(day, -30, GETDATE())
  AND it.CreativeID IS NULL;
```

---

## 3. UA media-mix reasoning

Given campaign KPIs (network, CPI, LTV, retention, SKAN installs, spend), prioritize investigation and budget allocation with explicit tradeoffs.

### Which networks to dig into first

- Estimate ROAS as LTV / CPI. Networks with the highest ROAS (historically including LiftOff, Digital Turbine, and Apple Search Ads in the sample) deserve deeper digs.
- Extreme CPI (highest or lowest) and gaps between reference installs vs SKAN installs can flag measurement or partner issues (e.g. large install–SKAN gaps on a low LTV/CPI network).

### Optimize media mix for ROAS + volume

| Spend target | Approach |
|--------------|----------|
| Maintain ~$707k/mo | Shift toward higher retention (D1–D30) networks; keep volume via efficient low-CPI partners |
| Cut to ~$400k/mo | Drop weak LTV &lt; CPI / low D30 partners; concentrate on efficient retention |
| Scale to ~$1M/mo | Double down on high volume + retention; raise bids carefully; test adjacent channels |

### In-network levers

- Targeting (behavior, device, category, interest)
- Creative and format A/B tests
- Funnel friction review and retargeting
- Data-driven bidding and post-install event optimization
- Deep links and cross-network learning where measurement allows
