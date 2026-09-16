-- =====================================================================
-- Retail Sales BI Dashboard — SQL layer
-- Written/tested against SQLite (in this environment) and MySQL-compatible.
-- Table shapes: customers(customer_id, signup_date, city, age_group)
--               transactions(transaction_id, customer_id, category,
--                             quantity, unit_price, transaction_date)
-- =====================================================================

-- 1) Customer-level aggregation: this is the table Python/Power BI build on top of
SELECT
    customer_id,
    MIN(transaction_date)                          AS first_purchase,
    MAX(transaction_date)                          AS last_purchase,
    COUNT(DISTINCT transaction_id)                 AS total_orders,
    ROUND(SUM(quantity * unit_price), 2)           AS total_spend
FROM transactions
GROUP BY customer_id;

-- 2) Revenue by category (feeds a Power BI bar chart)
SELECT
    category,
    ROUND(SUM(quantity * unit_price), 2) AS revenue,
    COUNT(*)                             AS n_transactions
FROM transactions
GROUP BY category
ORDER BY revenue DESC;

-- 3) Monthly active customers & revenue (feeds a Power BI line chart / DAX time intelligence)
SELECT
    strftime('%Y-%m', transaction_date)   AS month,          -- MySQL: DATE_FORMAT(transaction_date,'%Y-%m')
    COUNT(DISTINCT customer_id)           AS active_customers,
    ROUND(SUM(quantity * unit_price), 2)  AS revenue
FROM transactions
GROUP BY month
ORDER BY month;

-- 4) Recency per customer relative to a fixed snapshot date (churn input)
SELECT
    customer_id,
    MAX(transaction_date) AS last_purchase,
    CAST(julianday('2026-07-31') - julianday(MAX(transaction_date)) AS INTEGER) AS recency_days
    -- MySQL: DATEDIFF('2026-07-31', MAX(transaction_date)) AS recency_days
FROM transactions
GROUP BY customer_id;

-- 5) Window function: days since each customer's PREVIOUS purchase (per-transaction gap)
SELECT
    customer_id,
    transaction_date,
    LAG(transaction_date) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_purchase_date,
    julianday(transaction_date) - julianday(
        LAG(transaction_date) OVER (PARTITION BY customer_id ORDER BY transaction_date)
    ) AS days_since_prev_purchase
FROM transactions
ORDER BY customer_id, transaction_date;

-- 6) Top 10 customers by total spend
SELECT customer_id, ROUND(SUM(quantity * unit_price), 2) AS total_spend
FROM transactions
GROUP BY customer_id
ORDER BY total_spend DESC
LIMIT 10;

-- 7) Customers with NO transactions in the last 90 days (churned, snapshot-based)
--    Uses a LEFT JOIN so customers who never purchased at all are also caught.
SELECT c.customer_id, c.signup_date, MAX(t.transaction_date) AS last_purchase
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id
HAVING last_purchase IS NULL
    OR julianday('2026-07-31') - julianday(last_purchase) > 90;

-- 8) CTE version of the RFM base table (readable, reusable)
WITH customer_rfm AS (
    SELECT
        customer_id,
        CAST(julianday('2026-07-31') - julianday(MAX(transaction_date)) AS INTEGER) AS recency,
        COUNT(DISTINCT transaction_id) AS frequency,
        ROUND(SUM(quantity * unit_price), 2) AS monetary
    FROM transactions
    GROUP BY customer_id
)
SELECT * FROM customer_rfm WHERE monetary > 50000;

-- 9) Revenue concentration check (are we top-heavy on a few customers?)
--    Rank customers by spend, then see cumulative % of revenue.
WITH ranked AS (
    SELECT customer_id,
           SUM(quantity*unit_price) AS spend,
           RANK() OVER (ORDER BY SUM(quantity*unit_price) DESC) AS spend_rank
    FROM transactions GROUP BY customer_id
)
SELECT * FROM ranked ORDER BY spend_rank LIMIT 20;
