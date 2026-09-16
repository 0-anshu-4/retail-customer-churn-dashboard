"""
Retail Sales BI Dashboard — full analysis pipeline
SQL (via sqlite3) -> Pandas EDA -> RFM churn segmentation -> export for Power BI

Run: python3 retail_analysis.py
Outputs: customer_agg.csv, customer_rfm_segments.csv, segment_summary.csv
         (import these into Power BI to build the dashboard layer)
"""
import sqlite3
import numpy as np
import pandas as pd

SNAPSHOT_DATE = pd.Timestamp('2026-07-31')
CHURN_THRESHOLD_DAYS = 90   # chosen from the recency distribution (see below)

# ---------- 1. Load raw data into a real SQL engine ----------
conn = sqlite3.connect(':memory:')
customers = pd.read_csv('customers.csv')
transactions = pd.read_csv('transactions.csv', parse_dates=['transaction_date'])
customers.to_sql('customers', conn, index=False)
transactions.to_sql('transactions', conn, index=False)

# ---------- 2. SQL: aggregate to customer level (heavy lifting stays in the DB) ----------
customer_agg = pd.read_sql("""
    SELECT customer_id,
           MIN(transaction_date) AS first_purchase,
           MAX(transaction_date) AS last_purchase,
           COUNT(DISTINCT transaction_id) AS total_orders,
           ROUND(SUM(quantity * unit_price), 2) AS total_spend
    FROM transactions GROUP BY customer_id
""", conn, parse_dates=['first_purchase', 'last_purchase'])

# ---------- 3. Pandas: data-quality checks ----------
assert customer_agg['total_spend'].min() > 0, "found non-positive spend"
assert transactions['transaction_date'].max() <= SNAPSHOT_DATE, "future-dated transaction found"
print(f"No nulls in customer_agg: {customer_agg.isnull().sum().sum() == 0}")
print(f"Duplicate transaction_ids: {transactions['transaction_id'].duplicated().sum()}")

# ---------- 4. Feature engineering: Recency, Frequency, Monetary ----------
customer_agg['recency_days'] = (SNAPSHOT_DATE - customer_agg['last_purchase']).dt.days
customer_agg['frequency'] = customer_agg['total_orders']
customer_agg['monetary'] = customer_agg['total_spend']

# ---------- 5. Define churn from the data (not an arbitrary guess) ----------
print("\nRecency distribution (days since last purchase):")
print(customer_agg['recency_days'].describe(percentiles=[.5, .75, .9]))
customer_agg['status'] = np.where(
    customer_agg['recency_days'] > CHURN_THRESHOLD_DAYS, 'Churned', 'Active'
)
churn_rate = (customer_agg['status'] == 'Churned').mean() * 100
print(f"\nChurn rate (> {CHURN_THRESHOLD_DAYS}d inactive): {churn_rate:.2f}%")
print(f"Retention rate: {100 - churn_rate:.2f}%")

# ---------- 6. RFM scoring + segmentation ----------
customer_agg['R_score'] = pd.qcut(customer_agg['recency_days'], 5, labels=[5, 4, 3, 2, 1]).astype(int)
customer_agg['F_score'] = pd.qcut(customer_agg['frequency'].rank(method='first'), 5, labels=[1, 2, 3, 4, 5]).astype(int)
customer_agg['M_score'] = pd.qcut(customer_agg['monetary'], 5, labels=[1, 2, 3, 4, 5]).astype(int)
customer_agg['RFM_score'] = customer_agg[['R_score', 'F_score', 'M_score']].sum(axis=1)

def segment(row):
    if row['RFM_score'] >= 13:
        return 'Champions'
    elif row['RFM_score'] >= 10:
        return 'Loyal'
    elif row['RFM_score'] >= 7:
        return 'At Risk'
    return 'Lost'

customer_agg['segment'] = customer_agg.apply(segment, axis=1)

segment_summary = (
    customer_agg.groupby('segment')
    .agg(n_customers=('customer_id', 'count'),
         total_revenue=('monetary', 'sum'),
         avg_recency=('recency_days', 'mean'))
    .sort_values('total_revenue', ascending=False)
)
segment_summary['pct_customers'] = (segment_summary['n_customers'] / len(customer_agg) * 100).round(1)
segment_summary['pct_revenue'] = (segment_summary['total_revenue'] / customer_agg['monetary'].sum() * 100).round(1)
print("\nSegment summary:\n", segment_summary)

# ---------- 7. Export for Power BI ----------
customer_agg.to_csv('customer_agg.csv', index=False)
customer_agg.to_csv('customer_rfm_segments.csv', index=False)
segment_summary.to_csv('segment_summary.csv')
print("\nExported customer_agg.csv, customer_rfm_segments.csv, segment_summary.csv")
