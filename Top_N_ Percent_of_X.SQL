# Write a query to give users by those with the top 10% of searches (including ties)

SELECT user_id, 
searches 
FROM
(SELECT user_id, 
searches, 
RANK() OVER (ORDER BY searches) AS rank, 
COUNT(*) OVER() AS cnt
FROM a.a)
WHERE rank <= 0.1 * cnt

# Since it includes ties, use rank

# Write a query to give users by those with the top 10% of searches (not including ties)

SELECT user_id, 
searches 
FROM
(SELECT user_id, 
searches, 
ROW_NUMBER() OVER (ORDER BY searches) AS rownum, 
COUNT(*) OVER() AS cnt
FROM a.a)
WHERE rownum <= 0.1 * cnt
