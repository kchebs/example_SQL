-- Sports league + wellness incentive SQL examples
-- Companion write-up: docs/sports_league_sql.md

-- Q1a: at least 2 different sports in 2010
SELECT Person.FirstName, Person.LastName
FROM (
  SELECT DISTINCT Person.PersonID, Person.FirstName, Person.LastName, Sport.SportType
  FROM Sport
  INNER JOIN (Person INNER JOIN History ON Person.PersonID = History.PersonID)
    ON Sport.SportID = History.SportID
  WHERE YEAR(History.Timestamp) = 2010
) AS played
GROUP BY PersonID, Person.FirstName, Person.LastName
HAVING COUNT(1) > 1;

-- Q1b: at least 2 history rows in 2010 (same sport allowed)
SELECT Person.FirstName, Person.LastName
FROM History
INNER JOIN Person ON History.PersonID = Person.PersonID
WHERE YEAR(History.Timestamp) = 2010
GROUP BY Person.FirstName, Person.LastName
HAVING COUNT(1) > 1;

-- Q2: sport types never played
SELECT SportType
FROM Sport
WHERE SportID NOT IN (SELECT DISTINCT SportID FROM History);

SELECT DISTINCT SportType
FROM Sport
WHERE SportID NOT IN (SELECT DISTINCT SportID FROM History);

SELECT SportType
FROM Sport
LEFT OUTER JOIN History ON History.SportID = Sport.SportID
WHERE History.SportID IS NULL;

-- Q3: play counts including zeros
SELECT Sport.SportType,
       COUNT(History.SportID) AS TotalNumberOfTimesPlayed
FROM Sport
LEFT OUTER JOIN History ON History.SportID = Sport.SportID
GROUP BY Sport.SportType
ORDER BY COUNT(History.SportID) DESC;

-- Q4: MS Access pivot by date
TRANSFORM Sum(History.Score) AS SumOfScore
SELECT Person.FirstName, Person.LastName, Sport.SportName
FROM (History INNER JOIN Person ON History.PersonID = Person.PersonID)
INNER JOIN Sport ON History.SportID = Sport.SportID
GROUP BY Person.FirstName, Person.LastName, Sport.SportName
PIVOT Format(History.[Timestamp], "Short Date");

-- Q5: wellness incentive detail + control (MySQL-style export comments)
SELECT E.EmployerID, ILL.IncentiveValue
FROM Employer E
JOIN Accounts LA ON E.EmployerID = LA.EmployerID
JOIN IncentiveLevelLog ILL ON LA.AccountId = ILL.AccountId
UNION ALL
SELECT E.EmployerID, IncentiveValue * (2.0 / 3.0)
FROM Employer E
JOIN Accounts LA ON E.EmployerID = LA.EmployerID
JOIN IncentiveLevelLog ILL ON LA.AccountId = ILL.AccountId;
-- INTO OUTFILE 'Result.csv';

SELECT (COUNT(E.EmployerID)) * 2,
       SUM(IncentiveValue * (5.0 / 3.0)),
       NOW()
FROM Employer E
JOIN Accounts LA ON E.EmployerID = LA.EmployerID
JOIN IncentiveLevelLog ILL ON LA.AccountId = ILL.AccountId;
-- INTO OUTFILE 'CB.csv';
