# SQL Questions

The following examples are SQL code that I wrote to answer each respective prompt. Variations in SQL code can occur due to different database systems.

## Amazon Prime Video

### Table name - “streams”: streaming data of Prime Video customers. It contains information at a stream level, with data such as minutes streamed, buffers encountered while streaming, location, device used, and the customer ID.
Primary key - Stream_id
--stream id – one session (max at one episode)
### Example rows:
playback_date	stream_id   	device_id 	device_category	customer_id  	minutes_streamed	buffer_count	customer_country  
2017-01-01       	112344      	108         	Television          	YYTGBCSDFG      	12	0 	US  
2017-01-04       	927612192   	112         	Television          	HIGDSGKJAF      	34	10            	UK  
2017-04-03       	812618726   	179	Web Browser         	HJFGJLFFHJK     	80           	95              	IN  
2017-06-01       	921629712   	401         	Web Browser         	TEEWRJGHKJKG	238 	1	UK  
2017-12-05       	4982472376  	105         	Mobile              	KHGHJFDKLJHFF   	10 	5         	US  

### Table name - "transactions": contains information on transactions conducted by customers on Prime Video. 
Example rows:  
purchase_id  	purchase_date 	customer_id  
716219621   	2017-09-26 	ASKGASKAJSA  
918261982 	2017-03-30 	UKHJDLKGSDG  
984673876   	2017-12-16 	UPFASFJSHDV  
836453323   	2018-09-24 	AWETUYOIUBV  

### 1.	What country has the highest number of streams in the last 7 days?
Note: “Number of Streams” is count and not duration  
SELECT customer_country,  
COUNT(DISTINCT(stream_id)) number_of_streams  
FROM streams  
WHERE playback_date >= DATEADD(day, -7, GETDATE())  
GROUP BY customer_country  
ORDER BY COUNT(DISTINCT(stream_id)) DESC  
LIMIT 1  

### 2.	What is the monthly average # of streams from US in 2017?
SELECT AVG(number_of_streams) monthly_average_num_of_streams  
FROM  
(
SELECT MONTH(playback_date) playback_month,  
COUNT(DISTINCT(stream_id)) number_of_streams  
FROM streams  
WHERE customer_country = 'US' AND YEAR(playback_date) = 2017  
) as sub  

### 3.	On average in the UK, how many times does a customer stream in the same day that they purchase content?
SELECT SUM(number_of_streams)/SUM(number_of_purchases) uk_avg_customer  
FROM  
(
SELECT customer_id,  
COUNT(DISTINCT(CASE WHEN playback_date IS NOT NULL AND purchase_date IS NOT NULL THEN stream_id END)) number_of_streams,  
COUNT(DISTINCT(CASE WHEN playback_date IS NOT NULL AND purchase_date IS NOT NULL THEN purchase_id END)) number_of_purchases  
FROM streams s  
INNER JOIN transactions t ON s.customer_id = t.customer_id AND s.playback_date = t.purchase_date  
WHERE customer_country = 'UK'  
GROUP BY customer_id  
) as sub  

### 4.	Are there higher number of streams on the weekdays or weekend? 
Note: Friday is considered a weekday  
SELECT  
AVG(CASE WHEN day_num IN (0, 1, 2, 3, 4) THEN stream_num END) weekday,  
AVG(CASE WHEN day_num IN (5, 6) THEN stream_num END) weekend  
FROM  
(
SELECT WEEKDAY(playback_date) day_num,  
COUNT(DISTINCT(stream_id)) stream_num  
FROM streams  
GROUP BY WEEKDAY(playback_date)  
) as sub  

### 5.	Identify the top 3 countries with most number of hours per customer?
SELECT customer_country,  
SUM(minutes_streamed)/(60*COUNT(DISTINCT(customer_id))) as hours  
FROM streams  
GROUP BY customer_country  
ORDER BY SUM(minutes_streamed)/(60*COUNT(DISTINCT(customer_id))) DESC  
LIMIT 3  

### 6.	How would you define binge watching (do not worry about titles) based on number of hours watched by a customer? Identify the number of binge watchers in India (IN) in 2017.
Binge Watchers: > Median Total Stream Time  
Note: Use median if database system offers it  
SELECT COUNT(*) india_binge_watchers_cnt  
FROM  
(
SELECT customer_id  
FROM  
(
SELECT  
AVG(stream_time) as median  
FROM  
(
SELECT customer_id,  
SUM(minutes_streamed) stream_time,  
Row_number() OVER (ORDER BY SUM(minutes_streamed)) as row_id,  
(SELECT count(*) from streams WHERE customer_country = 'IN' and YEAR(playback_date) = 2017) as count  
FROM streams  
WHERE customer_country = 'IN' and YEAR(playback_date) = 2017  
GROUP BY customer_id  
) as subsub  
WHERE row_id BETWEEN count/2.0 and count/2.0 + 1  
) as sub  
WHERE customer_country = 'IN' and YEAR(playback_date) = 2017  
GROUP BY customer_id  
HAVING SUM(minutes_streamed) > median  
) as last  

## Babylon Health SQL interview test

### Question 1.
GPaH (GP at hand) is one of our key services. Not everyone in the UK is eligible for it, and patients have to sign up for it after they’ve created a Babylon account. Assume you have these two tables: accounts and gpah_reg.

### a) How many patients have created an account with Babylon in the last year?

Assuming the account_id is a primary key for the accounts table, the SQL query is:

SELECT COUNT(*) FROM accounts WHERE account_created_date >= DATEADD(year,-1,GETDATE())

### b) For the users who are eligible for gpah, what proportion of them actually register for it?

SELECT SUM(CASE WHEN gpah_reg_date IS NOT NULL THEN 1 ELSE 0 END)/ SUM(CASE WHEN gpah_eligible IS TRUE THEN 1 ELSE 0 END) prp_reg_oo_elig  
FROM accounts a  
LEFT JOIN gpah_reg g ON a.account_id = g.account_id  

### c) Over 2018, how has the registration rate to GPaH changed (by month)?

SELECT date_trunc(‘month’, account_created_date) as date,  
SUM(CASE WHEN gpah_eligible = True and gpah_reg_date IS NOT NULL then 1 else 0 END)/SUM(CASE WHEN gpah_eligible = True then 1 else 0 END) as months_rate,  
100 * (SUM(CASE WHEN gpah_eligible = True and gpah_reg_date IS NOT NULL then 1 else 0 END)/SUM(CASE WHEN gpah_eligible = True then 1 else 0 END) - lag(SUM(CASE WHEN gpah_eligible = True and gpah_reg_date IS NOT NULL then 1 else 0 END)/SUM(CASE WHEN gpah_eligible = True then 1 else 0 END), 1) over (order by account_created_date)) / lag(SUM(CASE WHEN gpah_eligible = True and gpah_reg_date IS NOT NULL then 1 else 0 END)/SUM(CASE WHEN gpah_eligible = True then 1 else 0 END), 1) over (order by account_created_date)) || '%' as MoM_change  
FROM accounts ac  
LEFT JOIN gpah_reg gr ON ac.account_id = gr.account_id  
WHERE date_part(‘year’, account_created_date) = 2018  
GROUP BY date_trunc(‘month’, account_created_date)  
ORDER BY date_trunc(‘month’, account_created_date) ASC  

### d) Where patients signed up for GPaH in 2018, what is the median latency between them creating a babylon account, and when they completed a registration for gpah?

SELECT PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY (DATEDIFF(day, account_created_date, gpah_reg_date)) AS median_latency  
FROM accounts ac  
LEFT JOIN gpah_reg gr ON ac.account_id = gr.account_id  
WHERE date_part(‘year’, gpah_reg_date) = 2018  

### e) Why would I ask for the median latency rather than the mean latency?

Median is better situated for skewed data. Latency could have some infrequent but very high values that would not represent the majority of the data and thus can cause misleading conclusions if the mean was used.

### Question 2.

Babylon allows users to book appointments with GPs via their phone. This also means that we need to actually schedule GPs to be available for those appointments. The appointments are scheduled in 10 minute blocks, but the GPs are scheduled for several hours at a time. Each GP can only see one patient at a time. Assume you have these 3 tables: slots, booked_gp_slots, and requested_appointment_slots.
 
### a) How many gps were available versus how many appointment requests there were for every time slot in the slots table.

SELECT slots, count(distinct(CASE WHEN request_appt_start IS NOT NULL THEN patient_id END)) num_of_requests, COUNT(DISTINCT(CASE WHEN slots >= book_slot_start and slots < booked_slot_end THEN gp_id END)) num_of_avail_gps  
FROM slots s  
LEFT JOIN requested_appointment_slots ra ON s.slots = ra.requested_appt_start  
CROSS JOIN booked_gp_slots  
GROUP BY slots

### b) Why do you think Babylon would care about this analysis?

This would provide insights on utilization. Babylon would be able to see if they need more/less/or the same number of GPs to handle the number of patients at a certain time.


