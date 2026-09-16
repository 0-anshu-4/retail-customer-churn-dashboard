-- =====================================================================
-- Retail Sales BI Dashboard — SQL queries in MySQL syntax
-- Assumes tables already created and loaded:
--   customers(customer_id, signup_date, city, age_group)
--   transactions(transaction_id, customer_id, category,
--                 quantity, unit_price, transaction_date)
-- =====================================================================

-- 1) Customer-level aggregation
SELECT
    customer_id,
    MIN(transaction_date)                AS first_purchase,
    MAX(transaction_date)                AS last_purchase,
    COUNT(DISTINCT transaction_id)       AS total_orders,
    ROUND(SUM(quantity * unit_price), 2) AS total_spend
FROM transactions
GROUP BY customer_id;

-- 2) Revenue by category
SELECT
    category,
    ROUND(SUM(quantity * unit_price), 2) AS revenue,
    COUNT(*)                             AS n_transactions
FROM transactions
GROUP BY category
ORDER BY revenue DESC;

-- 3) Monthly active customers & revenue
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m') AS month,
    COUNT(DISTINCT customer_id)            AS active_customers,
    ROUND(SUM(quantity * unit_price), 2)   AS revenue
FROM transactions
GROUP BY month
ORDER BY month;

-- 4) Recency per customer relative to a fixed snapshot date
SELECT
    customer_id,
    MAX(transaction_date) AS last_purchase,
    DATEDIFF('2026-07-31', MAX(transaction_date)) AS recency_days
FROM transactions
GROUP BY customer_id;

-- 5) Window function: days since each customer's PREVIOUS purchase
SELECT
    customer_id,
    transaction_date,
    LAG(transaction_date) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_purchase_date,
    DATEDIFF(
        transaction_date,
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

-- 7) Customers with NO transactions in the last 90 days (LEFT JOIN)
SELECT c.customer_id, c.signup_date, MAX(t.transaction_date) AS last_purchase
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.signup_date
HAVING last_purchase IS NULL
    OR DATEDIFF('2026-07-31', last_purchase) > 90;

-- 8) CTE version of the RFM base table
WITH customer_rfm AS (
    SELECT
        customer_id,
        DATEDIFF('2026-07-31', MAX(transaction_date)) AS recency,
        COUNT(DISTINCT transaction_id) AS frequency,
        ROUND(SUM(quantity * unit_price), 2) AS monetary
    FROM transactions
    GROUP BY customer_id
)
SELECT * FROM customer_rfm WHERE monetary > 50000;

-- 9) Revenue concentration (RANK)
WITH ranked AS (
    SELECT customer_id,
           SUM(quantity*unit_price) AS spend,
           RANK() OVER (ORDER BY SUM(quantity*unit_price) DESC) AS spend_rank
    FROM transactions GROUP BY customer_id
)
SELECT * FROM ranked ORDER BY spend_rank LIMIT 20;
