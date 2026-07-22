# Sports League SQL Examples

Personal SQL examples over a sports participation schema (`Person`, `Sport`, `History`) plus a wellness-employer incentive export pattern.

Assumed model for questions 1–4:

- `Person(PersonID, FirstName, LastName)`
- `Sport(SportID, SportType, SportName)`
- `History(PersonID, SportID, Timestamp, Score)`

Executable queries: [`../sql/sports_league_queries.sql`](../sql/sports_league_queries.sql).

## 1. Members who played at least 2 sports in 2010

**Different sports** (e.g. baseball and soccer):

```sql
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
```

**Any 2+ history rows in 2010** (same sport counted twice):

```sql
SELECT Person.FirstName, Person.LastName
FROM History
INNER JOIN Person ON History.PersonID = Person.PersonID
WHERE YEAR(History.Timestamp) = 2010
GROUP BY Person.FirstName, Person.LastName
HAVING COUNT(1) > 1;
```

## 2. Sport types that no one has ever played

Including duplicate type labels if present:

```sql
SELECT SportType
FROM Sport
WHERE SportID NOT IN (SELECT DISTINCT SportID FROM History);
```

Distinct type labels only:

```sql
SELECT DISTINCT SportType
FROM Sport
WHERE SportID NOT IN (SELECT DISTINCT SportID FROM History);
```

Anti-join alternative:

```sql
SELECT SportType
FROM Sport
LEFT OUTER JOIN History ON History.SportID = Sport.SportID
WHERE History.SportID IS NULL;
```

`LEFT OUTER JOIN` keeps every `Sport` row; unmatched sports have `NULL` history keys and are filtered in the `WHERE` clause.

## 3. Play counts by SportType (include unplayed)

```sql
SELECT Sport.SportType,
       COUNT(History.SportID) AS TotalNumberOfTimesPlayed
FROM Sport
LEFT OUTER JOIN History ON History.SportID = Sport.SportID
GROUP BY Sport.SportType
ORDER BY COUNT(History.SportID) DESC;
```

`COUNT(History.SportID)` treats unmatched sports as 0 because `NULL`s are not counted.

## 4. Pivot scores by game date (MS Access)

Returns one row per person/sport with dates as columns (crosstab / pivot):

```sql
TRANSFORM Sum(History.Score) AS SumOfScore
SELECT Person.FirstName, Person.LastName, Sport.SportName
FROM (History INNER JOIN Person ON History.PersonID = Person.PersonID)
INNER JOIN Sport ON History.SportID = Sport.SportID
GROUP BY Person.FirstName, Person.LastName, Sport.SportName
PIVOT Format(History.[Timestamp], "Short Date");
```

Reference: [Creating cross-tab queries and pivot tables in SQL](https://www.red-gate.com/simple-talk/sql/t-sql-programming/creating-cross-tab-queries-and-pivot-tables-in-sql/).

## 5. Wellness incentive detail + control file

Schema:

| Table | Columns |
|-------|---------|
| `Accounts` | `AccountId` PK, `EmployerID`, `Email`, `Name` |
| `Employer` | `EmployerID` PK, `EmployerName`, `ProgramName`, colors |
| `IncentiveLevelLog` | `AccountId`, `IncentiveLevel`, `DateCreated`, `DateEarned`, `IncentiveValue` |

Assumptions: three incentive levels worth `$100` / `$250` / `$500`. Goal: detail rows for incentive value and imputed income (`2/3` of incentive), plus a control file with count, sum, and run date.

```sql
-- Detail: incentive value + imputed income (2/3)
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

-- Control / balance
SELECT (COUNT(E.EmployerID)) * 2,
       SUM(IncentiveValue * (5.0 / 3.0)),
       NOW()
FROM Employer E
JOIN Accounts LA ON E.EmployerID = LA.EmployerID
JOIN IncentiveLevelLog ILL ON LA.AccountId = ILL.AccountId;
-- INTO OUTFILE 'CB.csv';
```
