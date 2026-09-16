# Interview Prep: Retail BI Dashboard + Gym Analytics Database

---

## PART 1 — HOW YOU COULD HAVE REALISTICALLY BUILT EACH PROJECT

### Project 1: Retail Sales BI Dashboard

**Pipeline:** Raw transaction data → SQL (extraction/aggregation) → Python EDA → Customer segmentation → Metrics → Power BI → Insights → Recommendations

**The realistic dataset** would look like a typical retail transactions table:

```
transactions: transaction_id, customer_id, product_id, category, quantity,
              unit_price, transaction_date, store_id, payment_method
customers:    customer_id, signup_date, city, age_group
products:     product_id, product_name, category, cost_price
```

**Step-by-step realistic workflow:**

1. **Problem framing.** "Why are customers churning?" is too vague to analyze directly. You narrow it to something testable: *"What fraction of customers who purchased in the last 90 days did NOT purchase in the following 90 days, and does that differ by segment/category?"* — that's a concrete, measurable question.

2. **SQL extraction.** You wouldn't dump the whole table into Python. You'd write SQL to pre-aggregate at the customer level (last purchase date, total spend, order count, favorite category) because doing this in the database is faster than looping in Python.

```sql
SELECT customer_id,
       MIN(transaction_date) AS first_purchase,
       MAX(transaction_date) AS last_purchase,
       COUNT(DISTINCT transaction_id) AS total_orders,
       SUM(quantity * unit_price) AS total_spend
FROM transactions
GROUP BY customer_id;
```

3. **Python/Pandas EDA.** Load that aggregated table into a DataFrame. Check nulls, duplicates, weird dates (transaction dates in the future, negative quantities). Compute `recency_days = today - last_purchase`. Plot the distribution of recency to spot a natural cutoff for "churned."

4. **Defining churn.** Since there's no `is_churned` column in raw retail data, you define it operationally: a customer is "churned" if `recency_days > N` (commonly 60–90 days, chosen by looking at the typical repurchase gap in the data — e.g. via a histogram of days-between-orders).

5. **Segmentation.** Bucket customers using RFM (Recency, Frequency, Monetary) — e.g. quantile-based scoring 1–5 on each dimension, then combine into segments like "Champions," "At Risk," "Lost."

6. **Metrics.** Churn rate, retention rate, average order value, revenue contribution by segment.

7. **Power BI.** Import the customer-level table (from SQL or a Python-exported CSV), build a data model, create DAX measures for churn rate/retention/revenue, and build visuals: KPI cards for headline numbers, a bar chart of revenue by segment, a line chart of monthly active customers, a table for drill-down.

8. **Insight → recommendation.** E.g., "40% of revenue comes from 15% of customers (Champions), but the At-Risk segment is large and trending toward churn — recommend a targeted win-back campaign (discount/email) for At-Risk customers whose recency is 45–90 days."

**Be ready to admit the honest scope:** this is very likely a project built on a single synthetic/Kaggle-style retail dataset, not a live production pipeline. That's fine — say so if asked. Don't imply real-time data or a live company.

### Project 2: Gym Operations & Business Analytics Database

**Pipeline:** Requirements → ER model → Relational schema → Normalization → MySQL tables → Constraints → Procedures/Functions/Triggers → Queries/Views → Reports

1. **Requirements.** A gym needs to track: who its members are, what plans they're on, whether they paid, whether they show up, which trainers run which sessions/classes, and which branch/equipment is involved.

2. **ER modeling.** Identify entities (Member, Plan, Payment, Attendance, Trainer, Class, ClassBooking, Branch, Staff, Equipment) and their relationships (a Member has many Payments; a Class has many Members through a booking junction table — many-to-many).

3. **Normalization.** Start from a flat "everything in one sheet" idea (member name, plan name, trainer name, all repeated per row) and normalize it into 1NF → 2NF → 3NF to eliminate repeated groups and partial/transitive dependencies (detailed in Part 6).

4. **MySQL implementation.** CREATE TABLE statements with PRIMARY KEY / FOREIGN KEY constraints, NOT NULL, UNIQUE, CHECK constraints.

5. **Procedures/Functions/Triggers.** Encapsulate repeated logic in the database layer — e.g., a procedure to register a new member + their first payment atomically; a function to compute membership duration; a trigger to auto-update a member's `status` when a payment is recorded.

6. **Reporting.** Views and JOIN-based queries answering operational questions: monthly revenue, attendance rate per class, top trainers by bookings, members nearing plan expiry.

---

## PART 2 — TECHNOLOGY-BY-TECHNOLOGY

### SQL
1. **What:** Structured Query Language — declarative language for querying/manipulating relational data.
2. **Why here:** The raw transactional/operational data lived in tables; SQL is the natural way to filter, aggregate, and join it before analysis.
3. **Problem solved:** Efficient set-based aggregation at the database layer instead of pulling millions of rows into memory.
4. **How:** You describe *what* result you want (SELECT ... WHERE ... GROUP BY), and the query engine figures out *how* to get it (execution plan).
5. **Example:** The customer-aggregation query in Part 1.
6. **Alternative:** Pull raw data into Pandas and do everything there.
7. **Why SQL instead:** Databases are optimized (indexes, query planner) for aggregation over large data — much faster and more memory-efficient than doing it row-by-row in Python.
8. **Interview Qs:** "Why not just do this in Pandas?" / "What's the execution order of a SQL query?" (FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY).

### Python
1. **What:** General-purpose programming language, widely used for data analysis.
2. **Why here:** SQL is great at aggregation but weak at statistical analysis, iterative feature engineering, and visualization prototyping.
3. **Problem solved:** Flexible, code-based analysis — RFM scoring, correlation checks, ad-hoc calculated columns.
4. **How:** Data loaded into a DataFrame (tabular in-memory structure); vectorized operations avoid explicit loops.
5. **Example:** `df['recency_days'] = (pd.Timestamp.today() - df['last_purchase']).dt.days`.
6. **Alternative:** R, or doing more of it in SQL/Excel.
7. **Why Python instead:** Ecosystem (Pandas/NumPy/plotting), reusability, easier to iterate on logic than deeply nested SQL.
8. **Interview Qs:** "Why Python after SQL and not instead of SQL?" → because SQL efficiently narrows/aggregates the data first; Python then does flexible analysis on the much smaller resulting table.

### Pandas
1. **What:** Python library for tabular data manipulation (DataFrames).
2. **Why here:** Cleaning, grouping, merging, and feature engineering on the customer-level dataset.
3. **Problem solved:** Avoids manual loops for row/group operations.
4. **How:** Vectorized operations under the hood use NumPy arrays.
5. **Example:** `df.groupby('segment')['total_spend'].sum()`.
6. **Alternative:** Excel, or pure SQL aggregation.
7. **Why Pandas instead:** More flexible for multi-step, conditional feature engineering (e.g., RFM scoring with `pd.qcut`) than SQL or Excel.
8. **Interview Qs:** "What did Pandas do that SQL couldn't?" → conditional/quantile-based scoring, iterative feature creation, easy merging of multiple aggregate tables, and stats functions.

### NumPy
1. **What:** Numerical computing library — arrays and vectorized math, which Pandas is built on top of.
2. **Why here:** Underlying numerical operations (mean, std dev, percentile cutoffs for segmentation) and array math.
3. **Problem solved:** Fast numerical computation without explicit Python loops.
4. **How:** Contiguous typed arrays + vectorized C-level operations.
5. **Example:** `np.percentile(df['total_spend'], 75)` to find a high-value cutoff.
6. **Alternative:** Pure Python loops (slow) or `statistics` module.
7. **Why NumPy instead:** Speed and integration with Pandas.
8. **Interview Qs:** "What's the difference between Pandas and NumPy?" → Pandas = labeled, heterogeneous, tabular (built on NumPy); NumPy = homogeneous, low-level, fast numerical arrays. Be honest: in most student projects NumPy's role is small — mainly through Pandas internals and simple statistical functions. Don't overclaim direct NumPy usage; say clearly what you used it for (e.g., percentile/threshold calculations) rather than vague hand-waving.

### Power BI
1. **What:** Microsoft's BI/visualization tool for building interactive dashboards.
2. **Why here:** Business stakeholders need an interactive, non-technical way to explore the churn/segmentation findings.
3. **Problem solved:** Turns static analysis into a self-serve, filterable dashboard.
4. **How:** Import data → Power Query cleans/shapes it → data model with relationships → DAX measures → visuals.
5. **Example:** A Churn Rate card, a bar chart of revenue by segment, a slicer by month.
6. **Alternative:** Tableau, Excel PivotTables/Charts, matplotlib static charts.
7. **Why Power BI instead:** Interactivity (slicers, drill-through), easy sharing, DAX for reusable business logic.
8. **Interview Qs:** "Why Power BI over Excel?" → interactivity, data modeling (star schema/relationships), DAX for centralized measure logic, better for recurring/refreshable reporting.

### MySQL
1. **What:** Open-source relational database management system.
2. **Why here:** Needed a real RDBMS to enforce constraints, relationships, and run procedural logic (procedures/triggers) — not just flat files.
3. **Problem solved:** Data integrity, structured storage, and server-side business logic.
4. **How:** Tables + constraints + SQL engine; InnoDB engine supports transactions and foreign keys.
5. **Example:** Foreign key from `Payment.member_id` → `Member.member_id`.
6. **Alternative:** PostgreSQL, SQL Server, SQLite.
7. **Why MySQL instead:** Free, widely used, good documentation, sufficient feature set (procedures/functions/triggers/views) for this project's scope.
8. **Interview Qs:** "Why MySQL over PostgreSQL?" — honest answer: familiarity/availability for a student project; you can acknowledge Postgres has richer features (e.g., better window function support historically, CHECK constraints enforcement) without pretending you evaluated both deeply unless you actually did.

### Stored Procedures / Functions / Triggers, JOINs, Subqueries, Views, Normalization
Covered in depth in Parts 6 and 7 below.

---

## PART 3 — SQL CONCEPT CARDS (project-anchored)

Format: **Concept → Explanation → Syntax → My project use → Interview Q → Strong answer**

**SELECT / WHERE / ORDER BY**
Basic retrieval + filtering + sorting.
```sql
SELECT member_name, join_date FROM Member WHERE status='Active' ORDER BY join_date DESC;
```
*Project use:* Listing active members. *Q:* "Order of execution of a query?" *A:* FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT — WHERE filters rows before grouping; HAVING filters after aggregation.

**GROUP BY / HAVING**
GROUP BY collapses rows into groups for aggregation; HAVING filters *those groups* (WHERE can't reference aggregates).
```sql
SELECT trainer_id, COUNT(*) AS sessions
FROM TrainingSession GROUP BY trainer_id HAVING COUNT(*) > 20;
```
*Project use:* Trainers with more than 20 sessions this month. *Q:* "Why HAVING and not WHERE?" *A:* Because the filter is on an aggregate (`COUNT(*)`), which doesn't exist yet at the WHERE stage — WHERE runs before grouping.

**DISTINCT / COUNT vs COUNT(\*) / COUNT(DISTINCT ...)**
`COUNT(*)` counts all rows (incl. NULLs); `COUNT(column)` ignores NULLs in that column; `COUNT(DISTINCT column)` counts unique non-null values.
*Project use:* `COUNT(DISTINCT customer_id)` for unique customers vs `COUNT(*)` for total transactions.
*Q:* "Difference between COUNT(\*) and COUNT(column)?" *A:* COUNT(\*) counts rows regardless of NULLs; COUNT(column) skips NULLs in that specific column.

**CASE WHEN**
Conditional logic inside SQL.
```sql
SELECT customer_id,
  CASE WHEN recency_days <= 30 THEN 'Active'
       WHEN recency_days <= 90 THEN 'At Risk'
       ELSE 'Churned' END AS status
FROM customer_agg;
```
*Project use:* Bucketing churn status directly in SQL for a Power BI-ready table.

**Aggregate functions (SUM/AVG/MIN/MAX)**
Standard, but know NULL behavior: aggregates ignore NULLs (except COUNT(\*)).

**JOINs**
- **INNER JOIN:** only matching rows in both tables.
- **LEFT JOIN:** all rows from left table, matched rows from right (NULLs if no match) — used to keep e.g. all members even those with zero payments.
- **RIGHT JOIN:** mirror of LEFT.
- **SELF JOIN:** table joined to itself (e.g., comparing trainers who share a branch).
- **CROSS JOIN:** Cartesian product — every row × every row; rarely intentional, but useful for generating a date×member matrix.
```sql
SELECT m.member_name, p.amount
FROM Member m LEFT JOIN Payment p ON m.member_id = p.member_id;
```
*Q:* "Why LEFT JOIN here instead of INNER?" *A:* Because I need members with *zero* payments to still appear (e.g., to flag them), and INNER JOIN would silently drop them.

**UNION vs UNION ALL**
UNION removes duplicates (implicit DISTINCT, costs a sort/dedup); UNION ALL keeps all rows and is faster. Use UNION ALL unless you specifically need deduplication.

**Subqueries vs Correlated Subqueries**
A subquery is a query nested inside another; it runs once (independent) unless it references the outer query's row — then it's *correlated* and runs once per outer row (slower).
```sql
-- correlated: find members who paid above their own branch's average
SELECT * FROM Payment p
WHERE amount > (SELECT AVG(amount) FROM Payment p2 WHERE p2.branch_id = p.branch_id);
```

**CTEs (WITH clause)**
Named temporary result set, improves readability over nested subqueries; can be recursive.
```sql
WITH customer_totals AS (
  SELECT customer_id, SUM(quantity*unit_price) AS spend
  FROM transactions GROUP BY customer_id
)
SELECT * FROM customer_totals WHERE spend > 10000;
```

**Window functions (ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD, PARTITION BY)**
Unlike GROUP BY, window functions compute a value *per row* while still having access to the group.
```sql
SELECT customer_id, transaction_date,
  LAG(transaction_date) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_purchase
FROM transactions;
```
*Project use:* This is exactly how you'd compute "days since previous purchase" for churn analysis — a very likely follow-up question. `RANK`/`DENSE_RANK` for ranking customers by spend; `ROW_NUMBER` to de-duplicate (keep first transaction per customer).

**Views**
A saved, named SELECT query that behaves like a virtual table — simplifies repeated complex joins, and can restrict access to certain columns.
```sql
CREATE VIEW MonthlyRevenue AS
SELECT DATE_FORMAT(payment_date,'%Y-%m') AS month, SUM(amount) AS revenue
FROM Payment GROUP BY month;
```

**Stored Procedures / Functions / Triggers** — see Part 7.

**Keys & Constraints**
- Primary key: uniquely identifies a row, not null.
- Foreign key: enforces referential integrity to another table's primary key.
- Candidate key: any column(set) that *could* be the primary key.
- Composite key: primary key made of 2+ columns (e.g., a ClassBooking junction table's `(member_id, class_id)`).
- Constraints: NOT NULL, UNIQUE, CHECK, DEFAULT.

**NULL handling / COALESCE / EXISTS / IN / BETWEEN / LIKE**
`COALESCE(x, 0)` substitutes a default when NULL. `EXISTS` checks row existence (often faster than `IN` on large subqueries because it can short-circuit). `LIKE '%gym%'` pattern matching.

**Indexes & Query Optimization**
An index is a data structure (typically B-tree) on a column that speeds up lookups/joins/filtering at the cost of extra storage and slower writes. You'd index foreign keys and frequently filtered columns (e.g., `member_id`, `transaction_date`). Optimization basics: avoid `SELECT *`, filter early, avoid functions on indexed columns in WHERE, use EXPLAIN to check the query plan.

**Transactions & ACID**
A transaction is a group of operations that succeed or fail together (`COMMIT`/`ROLLBACK`). ACID = Atomicity, Consistency, Isolation, Durability. Relevant to your "register member + first payment" procedure — both inserts should succeed together or not at all.

**Normalization (1NF/2NF/3NF) & Denormalization** — see Part 6.

---

## PART 4 — CHURN & RETENTION DEEP DIVE

- **Churn:** A customer stopping their relationship/purchasing behavior with the business.
- **Churn window:** The time period after which inactivity is *labeled* as churn (e.g., "no purchase in 90 days").
- **No explicit churn column?** You engineer the label from behavior: `recency_days = last_purchase_date_in_data − last_purchase_date_of_customer`. If `recency_days > threshold` → churned. The threshold is usually chosen from the data itself (e.g., 2× the median inter-purchase gap).
- **Retention rate:** `(customers active in period) / (customers active in previous period) × 100`.
- **Churn rate:** `100 − retention rate`, or `(customers lost in period) / (customers at start of period) × 100`.
- **Cohort analysis:** Group customers by their signup/first-purchase month, then track what % of each cohort is still active in months 1, 2, 3... — reveals whether retention is improving over time.
- **CLV (Customer Lifetime Value):** Roughly `average order value × purchase frequency × customer lifespan`.
- **RFM:** Recency (days since last purchase), Frequency (order count), Monetary (total/average spend) — score each 1–5 by quantile, combine into a segment (e.g., "555" = best customers).

**Example SQL for RFM base table:**
```sql
SELECT customer_id,
  DATEDIFF(CURDATE(), MAX(transaction_date)) AS recency,
  COUNT(DISTINCT transaction_id) AS frequency,
  SUM(quantity*unit_price) AS monetary
FROM transactions GROUP BY customer_id;
```

**Pandas side:**
- Cleaning: `df.isnull().sum()`, `df.drop_duplicates()`, `df.dropna()`/`fillna()`.
- Feature creation: `df['recency'] = (snapshot_date - df['last_purchase']).dt.days`.
- Segmentation: `pd.qcut(df['monetary'], 5, labels=[1,2,3,4,5])`.
- Merging: `pd.merge(customers_df, orders_agg_df, on='customer_id', how='left')`.

---

## PART 5 — POWER BI / DAX PREP

**Calculated Column vs Measure:** A calculated column is computed row-by-row and stored in the table (uses row context); a measure is computed on the fly based on the current filter context and is NOT stored (uses filter context). Prefer measures for aggregations — better performance, dynamic to slicers.

**Power Query vs DAX:** Power Query (M language) shapes/cleans data *before* it loads into the model (like ETL). DAX calculates *within* the model (measures/columns) after load.

**Report vs Dashboard:** A report is a multi-page, interactive Power BI file you build; a dashboard (Power BI Service concept) is a single-page pinned collection of visuals/tiles, often from multiple reports.

**Import vs DirectQuery:** Import loads a data snapshot into memory (fast, needs refresh); DirectQuery queries the live source on every interaction (always current, but slower, limited transformations).

**Star schema:** One central fact table (e.g., Transactions) surrounded by dimension tables (Customer, Product, Date) joined by keys — improves performance and simplifies DAX vs one flat wide table.

**Example DAX measures:**
```dax
Total Revenue = SUM(Transactions[Revenue])

Active Customers =
CALCULATE(DISTINCTCOUNT(Transactions[CustomerID]),
    Transactions[TransactionDate] >= TODAY()-90)

Churned Customers =
CALCULATE(DISTINCTCOUNT(Customer[CustomerID]), Customer[Status] = "Churned")

Churn Rate = DIVIDE([Churned Customers], DISTINCTCOUNT(Customer[CustomerID]), 0)

Retention Rate = 1 - [Churn Rate]

Avg Revenue per Customer = DIVIDE([Total Revenue], DISTINCTCOUNT(Transactions[CustomerID]), 0)
```
*Line-by-line for Churn Rate:* `DIVIDE(a, b, 0)` safely divides, returning 0 instead of erroring on divide-by-zero — this is a common DAX best practice over the raw `/` operator.

**Filter context vs row context:** Filter context = the set of filters (from slicers, visuals, or CALCULATE) applied when a measure evaluates. Row context = when iterating row-by-row (e.g., inside a calculated column, or a `SUMX`). `CALCULATE` is the function that lets you modify filter context.

**Why this visual?** Practice answering: KPI cards for single headline numbers (glanceable), bar charts for comparing categories (segment revenue), line charts for trends over time (monthly active customers), tables for row-level drill-down, slicers to let the user filter interactively without needing a new report.

---

## PART 6 — GYM DATABASE SCHEMA

**Sensible entity set (not all possible ones — pick what you can justify):**
`Member, MembershipPlan, Membership, Payment, Attendance, Trainer, TrainingSession, GymClass, ClassBooking, Branch, Staff, Equipment` (~12; "13+" — round out with e.g. `Feedback` or `EquipmentMaintenance` if that matches what you actually built — **verify your real table count before claiming a number**).

- `Member(member_id PK, name, dob, phone, email, branch_id FK)`
- `MembershipPlan(plan_id PK, plan_name, duration_months, price)`
- `Membership(membership_id PK, member_id FK, plan_id FK, start_date, end_date, status)`
- `Payment(payment_id PK, membership_id FK, amount, payment_date, method)`
- `Attendance(attendance_id PK, member_id FK, check_in, check_out)`
- `Trainer(trainer_id PK, name, specialization, branch_id FK)`
- `GymClass(class_id PK, class_name, trainer_id FK, schedule_time)`
- `ClassBooking(member_id FK, class_id FK, booking_date)` — **junction table** for the many-to-many between Member and GymClass (a member books many classes; a class has many members).
- `Branch(branch_id PK, location)`
- `Staff(staff_id PK, name, role, branch_id FK)`
- `Equipment(equipment_id PK, name, branch_id FK, purchase_date)`

**Cardinality:** Member–Membership is one-to-many (a member can have several membership periods over time). Member–GymClass is many-to-many, resolved via `ClassBooking`. Branch–Member is one-to-many.

**Normalization with a concrete before/after:**

*Unnormalized (flat) table:*
`member_id, member_name, plan_name, plan_price, trainer_name, class_name` — one row per booking, repeating member/plan/trainer info.

- **Insert anomaly:** Can't add a new plan until a member enrolls in it (no standalone Plan record).
- **Update anomaly:** If a plan's price changes, you must update every row that mentions it — miss one, and data is inconsistent.
- **Delete anomaly:** Deleting a member's last booking accidentally deletes the only record of the trainer's/class's existence.

**1NF:** Eliminate repeating groups/multi-valued fields — every cell atomic (e.g., don't store multiple phone numbers in one field).
**2NF:** Remove partial dependencies — every non-key column depends on the *whole* primary key, not part of it (relevant once you have composite keys, e.g. in `ClassBooking`).
**3NF:** Remove transitive dependencies — non-key columns shouldn't depend on other non-key columns (e.g., `plan_price` shouldn't sit in `Membership` if it's really an attribute of `MembershipPlan`).

This is fixed by splitting into the separate tables above, each with a clear single responsibility, linked by foreign keys.

---

## PART 7 — PROCEDURES, FUNCTIONS, TRIGGERS

| | Stored Procedure | Function | Trigger |
|---|---|---|---|
| Returns | Optional (can return nothing, or via OUT params) | Must return a single value | Nothing (fires automatically) |
| Called by | Explicit `CALL proc()` | Used inside SQL expressions: `SELECT func()` | Automatically on INSERT/UPDATE/DELETE |
| Can modify data | Yes | Generally restricted (esp. in SELECT context) | Yes (that's its main use) |
| Use case | Multi-step business operation | Reusable calculation | Enforce rules/auto-updates on data change |

**Procedure — register a member + first payment (atomic):**
```sql
DELIMITER //
CREATE PROCEDURE RegisterMember(IN p_name VARCHAR(100), IN p_plan_id INT, IN p_amount DECIMAL(10,2))
BEGIN
  DECLARE new_member_id INT;
  START TRANSACTION;
  INSERT INTO Member(name) VALUES (p_name);
  SET new_member_id = LAST_INSERT_ID();
  INSERT INTO Membership(member_id, plan_id, start_date, status) VALUES (new_member_id, p_plan_id, CURDATE(), 'Active');
  INSERT INTO Payment(membership_id, amount, payment_date) VALUES (LAST_INSERT_ID(), p_amount, CURDATE());
  COMMIT;
END //
DELIMITER ;
```

**Function — membership duration in months:**
```sql
CREATE FUNCTION MembershipDuration(m_id INT) RETURNS INT DETERMINISTIC
BEGIN
  DECLARE months INT;
  SELECT TIMESTAMPDIFF(MONTH, start_date, IFNULL(end_date, CURDATE())) INTO months
  FROM Membership WHERE membership_id = m_id;
  RETURN months;
END;
```

**Trigger — auto-update membership status after payment:**
```sql
CREATE TRIGGER after_payment_insert
AFTER INSERT ON Payment
FOR EACH ROW
UPDATE Membership SET status = 'Active' WHERE membership_id = NEW.membership_id;
```

**"Why not just do this in Python/app code?"** — Because the database layer enforces the rule *regardless of which application touches it* (web app, admin script, another service) — it's centralized, atomic, and can't be bypassed by forgetting to call app-side logic. Trade-off: business logic split between DB and app can become harder to debug/version-control than app-side logic — a fair critique to acknowledge.

---

## PART 8 — INTERVIEW QUESTION BANK (curated, high-yield)

**A/B. Overview & "tell me about your project"**
1. Walk me through your Retail BI project end to end.
2. Walk me through your Gym database end to end.
3. What was the business problem in each project?
4. What was your role — did you do this alone?
5. What was the hardest technical decision you made?

**C. Architecture/Design**
6. Why did you split work between SQL and Python instead of doing it all in one?
7. Why did you choose a star-schema-style model for Power BI?
8. How would this pipeline change with 10 million transactions instead of 10,000?

**D/E. SQL/MySQL**
9. Explain the difference between WHERE and HAVING with an example from your project.
10. Write a query to find the top 5 customers by total spend.
11. Write a query using a window function to find each customer's most recent purchase.
12. What's a correlated subquery, and did you use one?
13. Explain a JOIN you used and why you chose that JOIN type over another.
14. What indexes would you add to your Gym database and why?
15. Explain ACID and where it mattered in your `RegisterMember` procedure.

**F/G/H. Python/Pandas/NumPy**
16. How did you handle missing values in the transaction data?
17. How did you detect and handle duplicate transactions?
18. Walk me through how you computed recency/frequency/monetary.
19. What's the difference between `.apply()` and a vectorized operation, and which did you use?
20. What did NumPy specifically contribute versus Pandas?

**I. Power BI**
21. Difference between a measure and a calculated column — which did you use for Churn Rate and why?
22. Explain filter context using one of your measures.
23. Why a bar chart for segment revenue instead of a pie chart?
24. How would you set up a scheduled refresh if this were a live business dashboard?

**J. Data cleaning**
25. What data quality issues did you actually find?
26. How did you validate that your cleaning didn't introduce bias?

**K/L. Churn & segmentation**
27. How exactly did you define "churned"?
28. Why that specific time window and not a different one?
29. How did you validate your churn threshold was reasonable?
30. Explain RFM scoring and how you turned it into segments.

**M. Statistics**
31. What's the difference between mean and median, and when would you use each here?
32. Did you check for outliers in spend? How?

**N/O. Database design & normalization**
33. Why 3NF and not staying denormalized for simpler queries?
34. Give a real anomaly your normalization prevented.
35. What's a junction table, and where did you need one?

**P/Q/R. Procedures/Functions/Triggers**
36. Give a concrete example of a trigger you wrote and why.
37. What's a risk of using triggers heavily?
38. Why a function instead of just writing the calculation in every query?

**S. Performance**
39. How would you find and fix a slow query?
40. What does EXPLAIN show you?

**T. Business interpretation**
41. What's one insight that could plausibly change a business decision?
42. Who's the audience for this dashboard, and how does that shape what you show them?

**U/V. Debugging & edge cases**
43. What happens to your churn logic for a brand-new customer with only one purchase?
44. What if a customer has a data-entry error (transaction dated in the future)?

**W/X. Tradeoffs & failure**
45. What would you do differently if you rebuilt this?
46. What's a limitation of your churn definition?

**Y. Behavioral**
47. Tell me about a time your initial analysis approach didn't work and you changed it.
48. How did you decide when the analysis was "done enough" to present?

*(This is a representative high-yield set. Practice answering all of these out loud before your interview — you can ask me to generate more in any category.)*

---

## PART 9 — SKEPTICAL FOLLOW-UPS: WHAT A CONVINCING ANSWER NEEDS

- **"How exactly did you define churn?"** → State the specific threshold, *and* explain how you chose it (data-driven, not arbitrary) — e.g., "I looked at the distribution of days-between-purchases and picked 90 days because it was roughly 2 standard deviations beyond the median gap."
- **"Show me the SQL query you used."** → Be ready to actually write it, live, from memory — not just describe it in prose.
- **"Why Python after SQL?"** → SQL efficiently pre-aggregates; Python is where flexible, iterative feature engineering and stats happen on the much smaller resulting table.
- **"Why Pandas instead of doing everything in SQL?"** → Easier to iterate on multi-step conditional logic (RFM quantile scoring, merges across aggregate tables) without deeply nested SQL.
- **"What did NumPy actually do?"** → Name the specific calls (e.g., percentile thresholds) — don't claim vague "used for computation."
- **"How many records did you analyze?"** → Know your actual row/customer counts. If you don't remember the exact number, know the order of magnitude and say so honestly.
- **"How did you validate your results?"** → Sanity checks: totals reconciling with source data, spot-checking a few customers manually, checking segment sizes are reasonable (not 99% in one bucket).
- **"Why LEFT JOIN here / not INNER?"** → Because dropping unmatched rows would silently exclude customers/members with zero related records, which you need to see (e.g., zero-payment members).
- **"Why 13 tables?"** → Map to entities you can name — don't just say "for normalization," name what real-world objects each table represents.
- **"What would happen if you didn't normalize?"** → Update/insert/delete anomalies (give the concrete gym example from Part 6).
- **"Why a trigger instead of application logic?"** → Guarantees the rule fires no matter what touches the database; trade-off is logic split across layers.
- **"What was the most difficult part?"** → Pick something real and specific (e.g., choosing a churn threshold without ground-truth labels) rather than a generic answer.
- **"What did YOU personally build?"** → Be precise about solo vs group work; don't overclaim.

---

## PART 10 — RESUME CLAIM VALIDATION

**Bullet: "Queried transaction data with SQL and ran exploratory analysis in Python... to turn an ambiguous question into a concrete, testable analytical question."**
- *Means:* You went from "why are customers churning" (vague) to an operational, measurable definition (e.g., 90-day inactivity threshold).
- *Likely challenge:* "What made it 'ambiguous' — walk me through the exact reframing."
- *Must know:* Your actual churn threshold, why you chose it, and what the "testable" version of the question was.
- *Likely Qs:* Q27–29 above.
- *Answer structure:* Started question → what made it hard to test directly → how I operationalized it → what became measurable as a result.
- *Wording check:* Reasonable for a student project **if** you can actually explain the reframing process — don't just repeat the resume line.

**Bullet: "Segmented customers by usage and revenue contribution... delivered business-facing, action-ready recommendations."**
- *Means:* RFM-style or similar segmentation + at least one concrete, actionable recommendation tied to a segment.
- *Likely challenge:* "What was the actual recommendation, and what data supported it?"
- *Must know:* Your segment definitions and at least one specific recommendation with the number behind it (e.g., "X% of revenue from Y% of customers").
- **YOU NEED TO VERIFY THIS BEFORE SAYING IT IN AN INTERVIEW:** the exact numbers/percentages from your actual analysis — I don't have your real output, so don't quote invented figures.

**Bullet: "Designed a normalized relational schema (13+ tables) with stored procedures, functions, and triggers."**
- *Means:* You can name all 13+ tables, justify each one, and explain at least one real procedure/function/trigger you wrote.
- *Likely challenge:* "List the 13 tables" / "Show me one trigger."
- **YOU NEED TO VERIFY THIS:** your actual table names/count and at least one real procedure/trigger definition — use your real schema, not the example one above, when answering live.
- *Wording check:* Fine, as long as you can recite the real schema without hesitation.

**Bullet: "Wrote SQL reporting logic using JOINs, subqueries, and views..."**
- *Means:* At least one real view and one real multi-table JOIN query you can reproduce.
- *Likely challenge:* "Write one of your views from memory."
- **YOU NEED TO VERIFY THIS:** pull up your actual view definitions before the interview and practice writing them without looking.

---

## PART 11 — MOCK INTERVIEW (live, in chat)

I'll run this conversationally rather than in this document — one question at a time, scored, with feedback, increasing in difficulty, covering both projects. Say **"start mock interview"** when you're ready and I'll begin with: *"Tell me about your Retail Sales Business Intelligence Dashboard."*

---

## PART 12 — CRASH REVISION SHEET

**Top 30 SQL concepts:** SELECT/WHERE/GROUP BY/HAVING/ORDER BY, DISTINCT, CASE WHEN, COUNT vs COUNT(DISTINCT), SUM/AVG/MIN/MAX, INNER/LEFT/RIGHT/SELF/CROSS JOIN, UNION vs UNION ALL, subqueries vs correlated subqueries, CTEs, ROW_NUMBER/RANK/DENSE_RANK, LAG/LEAD, PARTITION BY, Views, Stored Procedures, Functions, Triggers, PK/FK/candidate/composite keys, constraints, COALESCE, EXISTS vs IN, BETWEEN, LIKE, Indexes, Query optimization/EXPLAIN, Transactions, ACID, 1NF/2NF/3NF, Denormalization.

**Top 20 Python/Pandas concepts:** DataFrame vs Series, `groupby`, `merge`/`join`, `apply` vs vectorized ops, `isnull`/`dropna`/`fillna`, `drop_duplicates`, `pd.qcut`/`pd.cut`, date arithmetic (`dt.days`), boolean filtering, `pivot_table`, `value_counts`, calculated columns, `astype`, `sort_values`, aggregation with multiple functions (`agg`), NumPy arrays vs lists, `np.percentile`, `np.where`, broadcasting, mean/median/std, correlation (`.corr()`).

**Top 20 Power BI/DAX concepts:** Power Query vs DAX, Import vs DirectQuery, star schema, fact vs dimension tables, relationships (1:many), calculated column vs measure, row context vs filter context, `CALCULATE`, `DIVIDE`, `SUMX` (iterator), slicers, drill-down vs drill-through, KPI cards, bookmarks, `DISTINCTCOUNT`, time intelligence basics, tooltips, report vs dashboard, refresh scheduling, why-this-visual reasoning.

**Top 15 database concepts:** ER modeling, entities/attributes, PK/FK, cardinality (1:1, 1:many, many:many), junction tables, normalization forms, anomalies (insert/update/delete), constraints, transactions/ACID, indexing, views, stored procedures vs functions vs triggers, denormalization trade-offs, data types, referential integrity.

**Top 15 churn/retention concepts:** Churn definition, churn window, retention rate formula, churn rate formula, cohort analysis, CLV, RFM (Recency/Frequency/Monetary), segmentation, at-risk vs high-value customers, recency calculation, purchase frequency, inactivity-based labeling, quantile-based scoring, churn threshold selection, validating a churn definition.

**Key formulas:**
- Retention Rate = Active customers this period / Active customers last period × 100
- Churn Rate = 1 − Retention Rate
- CLV ≈ Avg Order Value × Purchase Frequency × Customer Lifespan
- Recency = Snapshot date − Last purchase date

**Common interviewer traps:** asking you to write the exact query live, asking for exact numbers/counts from your project, asking "why not do it the other way," asking you to justify a specific design choice you may not have deeply considered originally.

**Common candidate mistakes:** vague answers ("I used Python for analysis" with no specifics), can't reproduce their own SQL/DAX live, inflating claims beyond what they can defend, not knowing basic normalization anomalies, confusing measure vs calculated column.

**20 questions you must be able to answer without hesitation:** Q1, Q6, Q9–13, Q16–20, Q27–30, Q33–36, Q41, Q45–46 from Part 8.

---

**Next step:** Reply "start mock interview" whenever you want to begin Part 11, and I'll ask the first question and score your answers one at a time.
