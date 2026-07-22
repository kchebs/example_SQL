-- Postgres-portable smoke assertions for sports league Q1–Q3.
-- Portfolio originals in sql/sports_league_queries.sql may use YEAR()/Access pivot;
-- this file proves schema + seed + core analytics logic on Postgres.

\set ON_ERROR_STOP on

-- Q1a: at least 2 different sports in 2010 → Ada only
CREATE TEMP TABLE q1a_expected (FirstName TEXT, LastName TEXT);
INSERT INTO q1a_expected VALUES ('Ada', 'Lovelace');

CREATE TEMP TABLE q1a_actual AS
SELECT p.FirstName, p.LastName
FROM Person p
JOIN History h ON p.PersonID = h.PersonID
JOIN Sport s ON h.SportID = s.SportID
WHERE EXTRACT(YEAR FROM h.Timestamp) = 2010
GROUP BY p.PersonID, p.FirstName, p.LastName
HAVING COUNT(DISTINCT s.SportType) > 1;

DO $$
BEGIN
  IF EXISTS (
    SELECT FirstName, LastName FROM q1a_actual
    EXCEPT
    SELECT FirstName, LastName FROM q1a_expected
  ) OR EXISTS (
    SELECT FirstName, LastName FROM q1a_expected
    EXCEPT
    SELECT FirstName, LastName FROM q1a_actual
  ) THEN
    RAISE EXCEPTION 'Q1a mismatch: actual=% expected=%',
      (SELECT COUNT(*) FROM q1a_actual),
      (SELECT COUNT(*) FROM q1a_expected);
  END IF;
END $$;

-- Q2: sport types never played → water (UnusedSwim)
CREATE TEMP TABLE q2_expected (SportType TEXT);
INSERT INTO q2_expected VALUES ('water');

CREATE TEMP TABLE q2_actual AS
SELECT SportType
FROM Sport
WHERE SportID NOT IN (SELECT DISTINCT SportID FROM History);

DO $$
BEGIN
  IF EXISTS (SELECT SportType FROM q2_actual EXCEPT SELECT SportType FROM q2_expected)
     OR EXISTS (SELECT SportType FROM q2_expected EXCEPT SELECT SportType FROM q2_actual) THEN
    RAISE EXCEPTION 'Q2 mismatch';
  END IF;
END $$;

-- Q3: play counts include zeros; water must be 0; soccer has 3 history rows
CREATE TEMP TABLE q3_actual AS
SELECT Sport.SportType,
       COUNT(History.SportID) AS TotalNumberOfTimesPlayed
FROM Sport
LEFT OUTER JOIN History ON History.SportID = Sport.SportID
GROUP BY Sport.SportType;

DO $$
DECLARE
  water_count INTEGER;
  soccer_count INTEGER;
BEGIN
  SELECT TotalNumberOfTimesPlayed INTO water_count FROM q3_actual WHERE SportType = 'water';
  SELECT TotalNumberOfTimesPlayed INTO soccer_count FROM q3_actual WHERE SportType = 'soccer';
  IF water_count IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'Q3 water count expected 0 got %', water_count;
  END IF;
  IF soccer_count IS DISTINCT FROM 3 THEN
    RAISE EXCEPTION 'Q3 soccer count expected 3 got %', soccer_count;
  END IF;
END $$;

SELECT 'sports_smoke OK' AS status;
