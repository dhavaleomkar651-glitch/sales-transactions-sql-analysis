# sales-transactions-sql-analysis
An end-to-end SQL project in MySQL: importing a messy flat CSV, auditing data quality, normalising it into a relational schema with primary and foreign keys, and answering 55 business and technical questions using joins, aggregations, subqueries, CTEs and window functions.

Author: Omkar Dhavale · LinkedIn Tools: MySQL 8, MySQL Workbench (Python/pandas used only to cross-check results)

1. Dataset
Item	Detail
File	Sales_transactions_2022-2025.csv
Raw rows	18,045
Columns	10 (Transaction_ID, Order_ID, Customer_ID, Customer_Name, Customer_Age, Customer_Gender, Customer_Segment, Order_Date, Order_Time, Sales_Channel)
Period	1 Jan 2022 – 31 Dec 2025
Customers	4,882 unique Customer_IDs
Orders	14,541 unique Order_IDs
Channels	Online, Retail Store, B2B Portal, Phone Order

The file has no price, quantity or product columns, so all analysis is based on transaction counts, not revenue.

2. Data quality issues found
Issue	Detail
Duplicate rows	45 Transaction_IDs appeared twice as exact duplicate rows (18,045 raw → 18,000 unique transactions). This blocked adding a primary key (Error 1062: Duplicate entry).
Inconsistent gender values	6 spellings for 3 real values: Female, FEMALE, Male, male, Non-binary, Non Binary.
Missing values	108 names, 218 ages and 162 genders are blank in the raw file.
Age outliers	Ages range from 4 to 112; the middle 50% of customers are 32–46.
Segment is not stable per customer	2,215 of 4,882 customers (45%) appear under more than one Customer_Segment (e.g. "New Customer" later becomes "Returning Customer"). Segment is therefore a transaction-level attribute, not a fixed customer attribute.
Repeated names	Many different customers share a name (1,087 names belong to more than one Customer_ID), so name cannot be used as an identifier.
3. Cleaning and schema design

Step 1: Load. The CSV is loaded as-is into a staging table sales_raw, which is never modified.

Step 2: Remove duplicates. ROW_NUMBER() OVER (PARTITION BY Transaction_ID ...) keeps one row per transaction, leaving 18,000 rows.

Step 3: Split the flat file into three tables and enforce integrity with keys:

customers                    channels                  transactions
---------------------        -------------------       ------------------------------
Customer_ID  (PK)    <---+   channel_id   (PK)  <--+   Transaction_ID (PK)
name                     |   channel_name (UNIQUE)  |   Order_ID
age                      |                          |   Customer_ID   (FK -> customers)
gender                   +--------------------------+   channel_id    (FK -> channels)
                                                        segment
                                                        Order_Date
                                                        Order_Time
sql
ALTER TABLE transactions
  ADD PRIMARY KEY (Transaction_ID),
  ADD CONSTRAINT fk_cust FOREIGN KEY (Customer_ID) REFERENCES customers(Customer_ID),
  ADD CONSTRAINT fk_chan FOREIGN KEY (channel_id)  REFERENCES channels(channel_id);

Step 4: Standardise gender.

sql
UPDATE customers
SET gender = CASE
    WHEN LOWER(gender) = 'male'                           THEN 'Male'
    WHEN LOWER(gender) = 'female'                         THEN 'Female'
    WHEN LOWER(REPLACE(gender,'-',' ')) = 'non binary'    THEN 'Non-binary'
    ELSE gender END;

Step 5: Keep segment on the transaction, not the customer, because it changes over time.

sql
ALTER TABLE transactions ADD COLUMN segment VARCHAR(30);

UPDATE transactions t
JOIN (SELECT DISTINCT Transaction_ID, Customer_Segment FROM sales_raw) r
  ON r.Transaction_ID = t.Transaction_ID
SET t.segment = r.Customer_Segment;

ALTER TABLE customers DROP COLUMN segment;

Step 6: Validate. Foreign keys can be tested by inserting a transaction for a non-existent customer, which should be rejected (Q52 in the SQL file). The headline results in section 4 were also cross-checked independently in pandas.

4. Key findings

All numbers are from the 18,000 de-duplicated transactions.

#	Finding	Result
1	Top channel	Online is the largest channel at 45.5% of transactions, followed by Retail Store (34.6%), B2B Portal (11.8%) and Phone Order (8.1%). Online is #1 in every customer segment.
2	Seasonality	December is the busiest month in all four years; November and December together account for about 24% of all transactions. The peak was Dec 2025 with 636 transactions, against a monthly average of 375. January is the slowest month.
3	Year-over-year trend	Transactions: 4,087 (2022) → 4,599 (2023, +12.5%) → 4,345 (2024, −5.5%) → 4,969 (2025, +14.4%).
4	Customer retention	58.6% of 2022 customers (1,522 of 2,596) bought again in 2023.
5	Repeat behaviour	75.8% of customers (3,700 of 4,882) made more than one transaction; the average is 3.7 transactions per customer and the maximum is 20.
6	Timing patterns	Weekdays carry 78% of transactions (weekends 22%). About 46% of all transactions happen between 1 PM and 6 PM, with 3 PM the busiest hour.
7	Customer mix	Consumer is the largest segment (44.6% of transactions), then Small Business (17.6%) and Returning Customer (13.7%). Premium is the smallest (4.4%).
5. What the SQL file covers

sql_practice_questions.sql contains 55 queries plus 5 bonus challenges:

Level	Topics
1	SELECT, WHERE, ORDER BY, LIMIT, NULL handling
2	GROUP BY, HAVING, aggregates, pivot-style counts
3	INNER / LEFT / SELF joins, multi-table joins
4	Subqueries, NOT EXISTS, CTEs, INTERSECT
5	ROW_NUMBER, RANK, LAG, NTILE, running totals, moving averages
6	CASE, date/time logic, retention, YoY growth, repeat-customer analysis
7	Indexes and EXPLAIN, views, transactions and rollback, foreign key tests, stored procedure
6. How to run it
Create the database and the sales_raw staging table, then import the CSV (Workbench Table Data Import Wizard works).
Run the cleaning and schema steps from section 3.
Open sql_practice_questions.sql and run the queries one at a time.
7. Limitations and next steps
No revenue, price or product data, so findings are volume-based only.
45% of customers change segment over time, so segment results are per transaction.
Missing age, name and gender values were left as NULL rather than imputed.
Next step: connect Power BI to the MySQL database and build a dashboard of monthly trends, channel mix and retention.
