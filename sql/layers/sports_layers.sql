-- dbt-style layer examples for the sports domain (reference only; not loaded by docker init).
-- See docs/dbt_style_layering.md

-- staging: one row per play event with typed year
-- stg_history
SELECT
  h.PersonID AS person_id,
  h.SportID AS sport_id,
  h.Timestamp AS played_at,
  EXTRACT(YEAR FROM h.Timestamp)::INTEGER AS play_year,
  h.Score AS score
FROM History h;

-- intermediate: person × sport × year participation
-- int_person_sport_year
SELECT
  p.PersonID AS person_id,
  p.FirstName AS first_name,
  p.LastName AS last_name,
  s.SportID AS sport_id,
  s.SportType AS sport_type,
  EXTRACT(YEAR FROM h.Timestamp)::INTEGER AS play_year,
  COUNT(*) AS play_events
FROM Person p
JOIN History h ON p.PersonID = h.PersonID
JOIN Sport s ON h.SportID = s.SportID
GROUP BY
  p.PersonID, p.FirstName, p.LastName,
  s.SportID, s.SportType,
  EXTRACT(YEAR FROM h.Timestamp);

-- mart: people with >1 distinct sport type in 2010
-- mart_multi_sport_2010
SELECT person_id, first_name, last_name
FROM (
  SELECT
    p.PersonID AS person_id,
    p.FirstName AS first_name,
    p.LastName AS last_name,
    COUNT(DISTINCT s.SportType) AS sport_types
  FROM Person p
  JOIN History h ON p.PersonID = h.PersonID
  JOIN Sport s ON h.SportID = s.SportID
  WHERE EXTRACT(YEAR FROM h.Timestamp) = 2010
  GROUP BY p.PersonID, p.FirstName, p.LastName
) t
WHERE sport_types > 1;

-- mart: play counts including sports never played
-- mart_sport_play_counts
SELECT
  s.SportType AS sport_type,
  COUNT(h.SportID) AS times_played
FROM Sport s
LEFT JOIN History h ON h.SportID = s.SportID
GROUP BY s.SportType;
