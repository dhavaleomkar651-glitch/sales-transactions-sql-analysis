create database sales_db;
use sales_db;
CREATE TABLE sales_raw (
    Transaction_ID VARCHAR(20),
    Order_ID VARCHAR(20),
    Customer_ID VARCHAR(20),
    Customer_Name VARCHAR(100),
    Customer_Age DECIMAL(5 , 1 ),
    Customer_Gender VARCHAR(20),
    Customer_Segment VARCHAR(30),
    Order_Date DATE,
    Order_Time TIME,
    Sales_Channel VARCHAR(30)
);
SELECT 
    COUNT(*)
FROM
    sales_raw;
SELECT 
    *
FROM
    sales_raw;


CREATE TABLE customers AS SELECT Customer_ID,
    MAX(Customer_Name) AS name,
    MAX(Customer_Age) AS age,
    MAX(Customer_Gender) AS gender,
    MAX(Customer_Segment) AS segment FROM
    sales_raw
GROUP BY Customer_ID;
alter table customers modify Customer_ID varchar(20) not null, add primary key (Customer_ID);
CREATE TABLE channels (
    channel_id INT AUTO_INCREMENT PRIMARY KEY,
    channel_name VARCHAR(30) UNIQUE
);
insert into channels (channel_name) select distinct Sales_Channel from sales_raw;
CREATE TABLE transaction AS SELECT r.Transaction_ID,
    r.Order_ID,
    r.Customer_ID,
    c.channel_id,
    r.Order_Date,
    r.Order_Time FROM
    sales_raw r
        JOIN
    channels c ON c.channel_name = r.Sales_Channel;
alter table transaction modify Transaction_ID varchar(20) not null, add primary key (Transaction_ID);
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Transaction_ID) AS unique_ids
FROM
    `transaction`;

SELECT 
    Transaction_ID, COUNT(*) AS times
FROM
    `transaction`
GROUP BY Transaction_ID
HAVING COUNT(*) > 1
ORDER BY times DESC;
SELECT 
    *
FROM
    `transaction`
WHERE
    Transaction_ID = 'T02005299';
CREATE TABLE transactions_clean AS
SELECT Transaction_ID, Order_ID, Customer_ID, channel_id, Order_Date, Order_Time
FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY Transaction_ID ORDER BY Order_Date, Order_Time) AS rn
  FROM `transaction` t
) x
WHERE rn = 1;
SELECT 
    COUNT(*), COUNT(DISTINCT Transaction_ID)
FROM
    transactions_clean;  -- numbers should match

ALTER TABLE transactions_clean
  MODIFY Transaction_ID VARCHAR(20) NOT NULL,
  ADD PRIMARY KEY (Transaction_ID);

ALTER TABLE transactions_clean
  ADD CONSTRAINT fk_cust FOREIGN KEY (Customer_ID) REFERENCES customers(Customer_ID),
  ADD CONSTRAINT fk_chan FOREIGN KEY (channel_id) REFERENCES channels(channel_id);
  DROP TABLE `transaction`;
RENAME TABLE transactions_clean TO transactions;
SELECT 
    t.*
FROM
    transactions_clean t
        LEFT JOIN
    customers c ON c.Customer_ID = t.Customer_ID
WHERE
    c.Customer_ID IS NULL;
SHOW CREATE TABLE transactions;-- or transactions_clean, depending on what you kept
SELECT 
    COUNT(*)
FROM
    transactions;
SELECT 
    ch.channel_name, COUNT(*) AS total
FROM
    transactions t
        JOIN
    channels ch ON ch.channel_id = t.channel_id
GROUP BY ch.channel_name
ORDER BY total DESC;


----- QUESTION_TO_SOLVE-------
-- =====================================================================
-- LEVEL 1: BASICS (SELECT, WHERE, ORDER BY, LIMIT)
-- =====================================================================
 
-- Q1. Show the first 10 transactions.
SELECT * FROM transactions LIMIT 10;
 
-- Q2. How many transactions, orders and customers are there?
SELECT COUNT(*)                    AS total_transactions,
       COUNT(DISTINCT Order_ID)    AS total_orders,
       COUNT(DISTINCT Customer_ID) AS total_customers
FROM transactions;
 
-- Q3. What are the distinct customer segments?
SELECT DISTINCT segment FROM customers;
 
-- Q4. Find the earliest and latest transaction date.
SELECT MIN(Order_Date) AS first_date, MAX(Order_Date) AS last_date FROM transactions;
 
-- Q5. List all transactions made in 2024.
SELECT * FROM transactions WHERE YEAR(Order_Date) = 2024;
-- =====================================================================
-- LEVEL 2: GROUP BY, HAVING, AGGREGATES
-- =====================================================================
 
-- Q1. Number of transactions per year.
SELECT YEAR(Order_Date) AS yr, COUNT(*) AS total_txns
FROM transactions
GROUP BY YEAR(Order_Date)
ORDER BY yr;
 
-- Q2. Number of transactions per month in 2024.
SELECT MONTH(Order_Date) AS mth, COUNT(*) AS total_txns
FROM transactions
WHERE YEAR(Order_Date) = 2024
GROUP BY MONTH(Order_Date)
ORDER BY mth;
 
-- Q3. Average, minimum and maximum age per segment.
SELECT segment, ROUND(AVG(age),1) AS avg_age, MIN(age) AS min_age, MAX(age) AS max_age
FROM customers
GROUP BY segment;
 
-- Q4. Customer count by gender.
SELECT gender, COUNT(*) AS customers FROM customers GROUP BY gender;
 
-- Q5. Customers who made more than 5 transactions.
SELECT Customer_ID, COUNT(*) AS txn_count
FROM transactions
GROUP BY Customer_ID
HAVING COUNT(*) > 5
ORDER BY txn_count DESC;
-- =====================================================================
-- LEVEL 3: JOINS
-- =====================================================================
 
-- Q1. INNER JOIN: each transaction with customer name, segment and channel.
SELECT t.Transaction_ID, t.Order_Date, c.name, c.segment, ch.channel_name
FROM transactions t
JOIN customers c  ON c.Customer_ID = t.Customer_ID
JOIN channels  ch ON ch.channel_id = t.channel_id;
 
 
-- Q2. Transactions per segment.
SELECT c.segment, COUNT(*) AS txns
FROM transactions t
JOIN customers c ON c.Customer_ID = t.Customer_ID
GROUP BY c.segment
ORDER BY txns DESC;
 
-- Q3. Top 10 customers by number of transactions (with names).
SELECT c.Customer_ID, c.name, COUNT(*) AS txns
FROM customers c
JOIN transactions t ON t.Customer_ID = c.Customer_ID
GROUP BY c.Customer_ID, c.name
ORDER BY txns DESC
LIMIT 10;
 
-- Q4. SELF JOIN: pairs of different customers who share the same name.
SELECT a.Customer_ID AS id_1, b.Customer_ID AS id_2, a.name
FROM customers a
JOIN customers b ON a.name = b.name AND a.Customer_ID < b.Customer_ID
ORDER BY a.name;
-- =====================================================================
-- LEVEL 4: SUBQUERIES AND CTEs
-- =====================================================================
 
-- Q1. Customers whose transaction count is above the average per customer.
SELECT Customer_ID, COUNT(*) AS txns
FROM transactions
GROUP BY Customer_ID
HAVING COUNT(*) > (
    SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM transactions GROUP BY Customer_ID) x
);
 
-- Q2. Customers who used 'Online' but never 'Retail Store'.
SELECT DISTINCT t.Customer_ID
FROM transactions t
JOIN channels ch ON ch.channel_id = t.channel_id
WHERE ch.channel_name = 'Online'
  AND NOT EXISTS (
      SELECT 1
      FROM transactions t2
      JOIN channels ch2 ON ch2.channel_id = t2.channel_id
      WHERE t2.Customer_ID = t.Customer_ID AND ch2.channel_name = 'Retail Store'
  );
 
-- Q3. Busiest month in each year (CTE + RANK).
WITH monthly AS (
    SELECT YEAR(Order_Date) AS yr, MONTH(Order_Date) AS mth, COUNT(*) AS txns
    FROM transactions
    GROUP BY YEAR(Order_Date), MONTH(Order_Date)
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY yr ORDER BY txns DESC) AS rnk FROM monthly
)
SELECT yr, mth, txns FROM ranked WHERE rnk = 1;
 
-- Q4. Customers who transacted in 2022 and again in 2025.
SELECT Customer_ID FROM transactions WHERE YEAR(Order_Date) = 2022
INTERSECT
SELECT Customer_ID FROM transactions WHERE YEAR(Order_Date) = 2025;
 
-- Q5. Customers who transacted in 2022 but NOT in 2023 (churned).
SELECT DISTINCT Customer_ID FROM transactions WHERE YEAR(Order_Date) = 2022
AND Customer_ID NOT IN (SELECT Customer_ID FROM transactions WHERE YEAR(Order_Date) = 2023);
-- =====================================================================
-- LEVEL 5: WINDOW FUNCTIONS
-- =====================================================================
 
-- Q1. Each customer's first transaction (ROW_NUMBER).
SELECT Customer_ID, Transaction_ID, Order_Date
FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Order_Date, Order_Time) AS rn
    FROM transactions t
) x
WHERE rn = 1;
 
-- Q2. Rank channels by transactions within each year.
SELECT yr, channel_name, txns,
       RANK() OVER (PARTITION BY yr ORDER BY txns DESC) AS rnk
FROM (
    SELECT YEAR(t.Order_Date) AS yr, ch.channel_name, COUNT(*) AS txns
    FROM transactions t
    JOIN channels ch ON ch.channel_id = t.channel_id
    GROUP BY YEAR(t.Order_Date), ch.channel_name
) x;
 
-- Q3. Running total of transactions by month.
WITH monthly AS (
    SELECT DATE_FORMAT(Order_Date, '%Y-%m') AS ym, COUNT(*) AS txns
    FROM transactions GROUP BY DATE_FORMAT(Order_Date, '%Y-%m')
)
SELECT ym, txns, SUM(txns) OVER (ORDER BY ym) AS running_total FROM monthly;
 
-- Q4. Days between each customer's consecutive transactions.
SELECT Customer_ID, Order_Date,
       DATEDIFF(Order_Date, LAG(Order_Date) OVER (PARTITION BY Customer_ID ORDER BY Order_Date)) AS days_since_prev
FROM transactions;



