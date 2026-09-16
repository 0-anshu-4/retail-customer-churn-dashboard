# Retail BI Project — Complete Study Guide

Use this alongside the actual files (`generate_data.py`, `retail_sql_queries.sql`,
`retail_analysis.py`, `retail_results.md`). This doc explains *why* each part
exists and what you need to be able to say about it without looking anything up.

---

## STEP 1 — Run the pipeline yourself

Order matters — each step's output feeds the next:

```
generate_data.py  →  customers.csv, transactions.csv
retail_sql_queries.sql  →  run each query against those CSVs (via sqlite3/MySQL)
retail_analysis.py  →  loads CSVs → SQL aggregation → Pandas RFM/churn → exports 3 CSVs
```

**What to be able to say:** "I generate the raw data, load it into a SQL
engine, aggregate to customer level with SQL, then do RFM/churn feature
engineering in Pandas, and export the result for Power BI." That one sentence
*is* the architecture — memorize it, because it answers "walk me through your
project" on its own.

---

## STEP 2 — The data generation logic (`generate_data.py`)

**What exists:** 600 customers, each assigned one of five hidden "behavior
types" that drives how they show up in the data:

| Behavior   | % of base | # orders | Recency pattern |
|------------|-----------|----------|------------------|
| loyal      | 12%       | 15–35    | very recent (1–20 days) |
| regular    | 28%       | 6–14     | recent-ish (5–45 days) |
| occasional | 30%       | 2–6      | moderate (20–90 days) |
| one_time   | 15%       | exactly 1| wide spread (30–400 days) |
| lapsed     | 15%       | 3–10     | old (120–400 days) |

**Why this matters for the interview:** a real interviewer will ask "what did
the raw data look like?" You need to say: customer-level fields (id, signup
date, city, age group) and a transaction-level table (transaction id,
customer id, category, quantity, unit price, date) — that's it, nothing
exotic. There is **no `is_churned` column** — that's the whole point of the
churn-definition exercise (see Step 5/6).

**Be honest if asked:** this is synthetic data built to have realistic
behavior spread, not a live company dataset. Say that plainly if asked —
don't imply otherwise.

---

## STEP 3 — Every SQL query, explained (`retail_sql_queries.sql`)

All 9 were tested and confirmed to run. Know what each one is *for*, not
just what it returns.

**1. Customer-level aggregation**
```sql
SELECT customer_id, MIN(transaction_date) AS first_purchase,
       MAX(transaction_date) AS last_purchase,
       COUNT(DISTINCT transaction_id) AS total_orders,
       ROUND(SUM(quantity*unit_price),2) AS total_spend
FROM transactions GROUP BY customer_id;
```
*Purpose:* Collapses thousands of transaction rows into one row per customer
— the base table everything else builds on. `COUNT(DISTINCT transaction_id)`
guards against any accidental duplicate rows per transaction.

**2. Revenue by category** — simple `GROUP BY category`, feeds a Power BI
bar chart. Talking point: revenue is nearly flat across categories
(₹3.55M–₹3.82M) — so category mix is *not* what explains churn; customer
behavior is. That's a real finding, not a guess.

**3. Monthly active customers & revenue** — `GROUP BY` on a truncated month
string. Feeds a trend line. `strftime('%Y-%m', ...)` in SQLite is
`DATE_FORMAT(date,'%Y-%m')` in MySQL — know that translation, it's a common
"how would this look in MySQL" question.

**4. Recency per customer** — `julianday(snapshot) - julianday(last_purchase)`.
In MySQL this is `DATEDIFF(snapshot, last_purchase)`. This single number
(`recency_days`) is the backbone of the churn label.

**5. Window function — days since previous purchase**
```sql
LAG(transaction_date) OVER (PARTITION BY customer_id ORDER BY transaction_date)
```
*Purpose:* Unlike GROUP BY (which collapses rows), this keeps every
transaction row but adds the *previous* transaction date for that same
customer, letting you compute the gap between consecutive purchases —
useful for understanding a customer's natural buying rhythm.
**Likely question:** "Why not just use MAX/MIN?" → Because MAX/MIN only
gives you the first and last purchase; LAG lets you see the gap between
*every consecutive pair*, which is what you'd actually use to validate that
90 days is a reasonable churn cutoff (are gaps normally much smaller than 90
days for active customers? yes).

**6. Top 10 customers by spend** — straightforward `ORDER BY ... LIMIT 10`.

**7. Customers with no activity in 90 days (LEFT JOIN)**
```sql
FROM customers c LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id
HAVING last_purchase IS NULL OR ... > 90;
```
*Purpose:* An INNER JOIN would silently drop any customer who has **zero**
transactions — exactly the customers you most need to flag. LEFT JOIN keeps
them, and `last_purchase IS NULL` catches them. **This is the single most
important JOIN-choice question you'll get** — have this answer ready
verbatim.

**8. CTE version of RFM base table** — same logic as query 1/4 wrapped in
`WITH customer_rfm AS (...)`. Purpose: readability and reusability when a
query needs to reference the aggregated table more than once, versus nesting
subqueries.

**9. Revenue concentration (RANK)**
```sql
RANK() OVER (ORDER BY SUM(quantity*unit_price) DESC) AS spend_rank
```
*Purpose:* Ranks customers by spend without collapsing rows — used to check
whether revenue is concentrated in a small number of customers (Pareto
check). Know the difference: `RANK()` leaves gaps after ties (1,1,3);
`DENSE_RANK()` doesn't (1,1,2); `ROW_NUMBER()` breaks ties arbitrarily
(1,2,3) even for equal values.

---

## STEP 4 — The Pandas/RFM pipeline (`retail_analysis.py`)

Trace this chain out loud until it's automatic:

```
customer_agg (from SQL)
   → recency_days = snapshot_date − last_purchase        [Recency]
   → frequency = total_orders                             [Frequency]
   → monetary = total_spend                                [Monetary]
   → status = 'Churned' if recency_days > 90 else 'Active'
   → R_score, F_score, M_score = pd.qcut(..., 5)           [1–5 each]
   → RFM_score = R_score + F_score + M_score                [3–15]
   → segment = Champions / Loyal / At Risk / Lost (by RFM_score band)
```

**`pd.qcut` in plain English:** it sorts customers by a metric and splits
them into 5 equal-sized buckets (quintiles), so the "top 20% most recent"
customers get a 5, the "bottom 20%" get a 1. It's *relative* scoring — a
score of 5 means "top fifth of this dataset," not an absolute threshold.

**Why `R_score` uses `labels=[5,4,3,2,1]` (reversed) but F/M use
`[1,2,3,4,5]`:** lower recency_days is *better* (more recent), so the
smallest recency values need to map to the highest score — the label order
is flipped on purpose. This is a real "gotcha" worth being able to explain
if someone reads your code closely.

**Data-quality checks actually run in the script:**
- `assert customer_agg['total_spend'].min() > 0` — no zero/negative spend rows.
- `assert transactions['transaction_date'].max() <= SNAPSHOT_DATE` — no
  future-dated transactions (a classic data-entry error).
- Null count check, duplicate `transaction_id` check.

Know these three checks by name — "how did you validate data quality" is a
guaranteed question, and "I checked for nulls, duplicates, and impossible
dates" is a concrete, credible answer.

---

## STEP 5 — The headline numbers (memorize these exactly)

From `retail_results.md`, all reproducible by rerunning `retail_analysis.py`:

- **Churn rate: 25.17%** | **Retention rate: 74.83%**
- Recency distribution: median 40 days, 75th percentile 92.5 days, 90th
  percentile 227 days
- Segments: **Champions** 135 customers (22.5%) → 55.4% of revenue |
  **Loyal** 118 (19.7%) → 21.3% | **At Risk** 171 (28.5%) → 18.0% |
  **Lost** 176 (29.3%) → 5.4%
- **Top 15% of customers by spend generate 44.5% of total revenue**
  (Pareto/revenue concentration finding)
- **119 customers (19.8%) sit in the 45–90 day at-risk window**,
  representing **₹1,802,342** in historical spend

---

## STEP 6 — Why 90 days, specifically (churn threshold justification)

Don't say "I picked 90 days." Say: *"I looked at the recency distribution
across all 600 customers — the median gap since last purchase was 40 days,
but it climbs steeply after that, reaching 227 days at the 90th percentile.
90 days sits past where normal repeat-purchase behavior would fall, but
before the long tail of clearly inactive customers — so it's a defensible
cutoff, not an arbitrary round number."*

If pushed further: *"It's a judgment call, not a universal constant — a
weekly-purchase grocery business would need a much shorter window than a
once-a-year big-ticket retailer. I'd want to validate it against actual
repeat-purchase-cycle data if this were a real production system."*

---

## STEP 7 — Skeptical follow-ups, answered with your real numbers

| Question | Your answer |
|---|---|
| "How exactly did you define churn?" | >90 days since last purchase, chosen from the recency distribution (see Step 6). |
| "Why LEFT JOIN in query 7 and not INNER?" | INNER JOIN would drop customers with zero transactions entirely — I need them visible so they get flagged as churned/never-active. |
| "Why Python after SQL, not instead of it?" | SQL does the heavy aggregation efficiently at the database layer; Pandas then does the flexible, iterative RFM scoring that's awkward to express in pure SQL (quantile-based conditional bucketing). |
| "How many records did you analyze?" | 600 customers, 4,252 transactions. |
| "How did you validate your results?" | Null/duplicate/future-date checks in code, plus sanity-checking that segment sizes weren't absurdly skewed (they're roughly 20–30% each, not 99% in one bucket). |
| "What's your single actionable recommendation?" | Target the 119 at-risk customers (45–90 day window, ₹18L historical spend) with a win-back campaign before they cross into the Lost segment, where average recency is 142 days and reactivation gets much harder. |
| "Is this real company data?" | No — synthetic data built with realistic behavior variation, generated by my own script. Be upfront about this. |

---

## STEP 8 — Mock interview

Once Steps 1–7 feel automatic (you can explain each without opening a file),
tell me to **start the mock interview**. I'll question you on this exact
project — same numbers, same queries — the way a real interviewer would,
score your answers, and flag anything shaky.
