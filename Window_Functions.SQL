''' Given an example table a with columns user_id, item_id, searches, and clicks; transform it into table b with format
user_id, item_id1, CTR1, item_id2, CTR2, item_id3, CTR3 which shows the summary of a user\'s CTR by item for only up to
3 items where click through rate (CTR) is clicks/searches. Table A\'s rows can have repeating user ids and item ids.

Table A.						
user_id	item_id	searches	clicks			
1234	990011	100	11			
1234	990012	20	1			
1212	990011	3	2			
1212	990013	4	3			
1212	990015	6	5			
1212	990017	7	5			
1200	990018	6	4			
1244	990019	3	3			
1244	990020	2	2			
1244	990021	30	3			

Table B						
user_id	item_id1	CTR1	item_id2	CTR2	item_id3	CTR3
1234	990011	11%	990012	5%		
1212	990011	67%	990013	75%	990015	83%
1200	…	…	…	…	…	…
1244	…	…	…	…	…	…

'''


SELECT
user_id,
MAX(CASE WHEN rn = 1 THEN item_id END) item_id1,
CONCAT(CAST(ROUND(SUM(CASE WHEN rn = 1 THEN clicks END)/SUM(CASE WHEN rn = 1 THEN searches END)*100) as string),"%") CTR1,
MAX(CASE WHEN rn = 2 THEN item_id END) item_id2,
CONCAT(CAST(ROUND(SUM(CASE WHEN rn = 2 THEN clicks END)/SUM(CASE WHEN rn = 2 THEN searches END)*100) as string),"%") CTR2,
MAX(CASE WHEN rn = 3 THEN item_id END) item_id3,
CONCAT(CAST(ROUND(SUM(CASE WHEN rn = 3 THEN clicks END)/SUM(CASE WHEN rn = 3 THEN searches END)*100) as string),"%") CTR3
FROM
(SELECT
user_id,
item_id,
SUM(clicks) clicks,
SUM(searches) searches,
ROW_NUMBER() OVER (PARTITION BY user_id
                   ORDER BY item_id ASC) AS rn
FROM a
GROUP BY user_id, item_id)
GROUP BY user_id
