Sales Transactions SQL Project (MySQL)

A MySQL project that takes a flat sales CSV, finds and fixes a data quality problem (duplicate transaction IDs), splits the data into a relational schema with primary and foreign keys, and then answers business questions using joins, aggregations, subqueries, CTEs and window functions.

Author: Omkar Dhavale · LinkedIn Tools: MySQL 8, MySQL Workbench Script: sales_db.sql

1. Dataset
Item	Detail
Source file	Sales_transactions_2022-2025.csv
Raw rows	18,045
Columns	10: Transaction_ID, Order_ID, Customer_ID, Customer_Name, Customer_Age, Customer_Gender, Customer_Segment, Order_Date, Order_Time, Sales_Channel
Period	1 Jan 2022 – 31 Dec 2025
After de-duplication	18,000 transactions, 14,541 orders, 4,882 customers
Channels	Online, Retail Store, B2B Portal, Phone Order

The file has no price, quantity or product columns, so all analysis is based on transaction counts, not revenue.

2. What the script does
Step 1: Staging table

The CSV is imported into sales_raw, a copy of the file with matching data types (DATE for dates, TIME for times, DECIMAL for age). It is kept untouched as the source of truth. The import itself is done with MySQL's import tools and is not part of the script.

Step 2: Split the flat file into three tables
customers                     channels                    transactions
----------------------        --------------------        ----------------------------
Customer_ID   (PK)     <--+   channel_id   (PK)     <--+  Transaction_ID  (PK)
name                      |   channel_name (UNIQUE)     |  Order_ID
age                       |                             |  Customer_ID    (FK -> customers)
gender                    +-----------------------------+  channel_id     (FK -> channels)
segment                                                    Order_Date
                                                           Order_Time
customers is built with GROUP BY Customer_ID so there is one row per customer, and Customer_ID becomes the primary key.
channels is a lookup table of the 4 distinct sales channels, with an auto-increment key.
transactions is built by joining sales_raw to channels to replace the channel text with channel_id.
Step 3: A real data problem, and the fix

Adding a primary key on Transaction_ID failed:

Error Code: 1062. Duplicate entry 'T02005299' for key 'transaction.PRIMARY'

Investigating with GROUP BY ... HAVING COUNT(*) > 1 showed 45 transaction IDs appear twice as exact duplicate rows (18,045 raw rows vs 18,000 unique IDs). They were removed with a window function, keeping one row per ID:

sql
CREATE TABLE transactions_clean AS
SELECT Transaction_ID, Order_ID, Customer_ID, channel_id, Order_Date, Order_Time
FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY Transaction_ID ORDER BY Order_Date, Order_Time) AS rn
  FROM `transaction` t
) x
WHERE rn = 1;
Step 4: Enforce integrity

Once the data was clean, the primary key and two foreign keys were added, the old table dropped, and the clean table renamed to transactions:

sql
ALTER TABLE transactions_clean
  MODIFY Transaction_ID VARCHAR(20) NOT NULL,
  ADD PRIMARY KEY (Transaction_ID);

ALTER TABLE transactions_clean
  ADD CONSTRAINT fk_cust FOREIGN KEY (Customer_ID) REFERENCES customers(Customer_ID),
  ADD CONSTRAINT fk_chan FOREIGN KEY (channel_id)  REFERENCES channels(channel_id);
Step 5: Validate

A LEFT JOIN between transactions and customers (filtering for NULL on the customer side) checks that no transaction points to a missing customer.

3. Analysis queries
Level	Topics	Examples
1. Basics	SELECT, WHERE, DISTINCT, MIN/MAX, COUNT	Row counts, date range, transactions in 2024
2. Group by	GROUP BY, HAVING, ORDER BY	Transactions per year and month, customers with more than 5 transactions
3. Joins	Multi-table JOIN, self join	Transactions with customer and channel names, top 10 customers, customers sharing a name
4. Subqueries and CTEs	Nested queries, NOT EXISTS, RANK, INTERSECT	Customers above average, online-only customers, busiest month per year, churned customers
5. Window functions	ROW_NUMBER, RANK, SUM() OVER, LAG	First purchase per customer, channel ranking per year, running totals, days between purchases
4. Results

Figures below are from the 18,000 de-duplicated transactions.

Transactions per channel

Channel	Transactions	Share
Online	8,195	45.5%
Retail Store	6,221	34.6%
B2B Portal	2,124	11.8%
Phone Order	1,460	8.1%

Transactions per year

Year	Transactions	Change
2022	4,087	n/a
2023	4,599	+12.5%
2024	4,345	−5.5%
2025	4,969	+14.4%

Other findings

Busiest month: December in every year (501 in 2022, 555 in 2023, 528 in 2024, 636 in 2025).
Returning customers: 1,572 customers bought in both 2022 and 2025.
Churn: 1,074 of the 2,596 customers who bought in 2022 did not buy in 2023, so 58.6% came back the next year.
5. Known limitations and next steps
Segment is not a stable customer attribute. 2,215 of 4,882 customers (45%) appear under more than one Customer_Segment (for example "New Customer" later becoming "Returning Customer"). The customers table currently keeps one value per customer using MAX(), so segment-based queries are approximations. A better design stores segment on transactions.
Gender needs standardising. The raw data has six spellings of three values (Male, male, Female, FEMALE, Non-binary, Non Binary).
Missing and odd values are left as-is: 108 names, 218 ages and 162 genders are blank, and ages range from 4 to 112.
No revenue data, so the analysis counts transactions only.
Next step: connect Power BI to this database for a dashboard of monthly trends, channel mix and customer retention.
6. How to run
Run sales_db.sql from the top to create the database and tables.
Import Sales_transactions_2022-2025.csv into sales_raw (Workbench: right-click the table, then Table Data Import Wizard).
Run the remaining statements in order, then the analysis queries one at a time.
