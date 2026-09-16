# Retail Sales BI Dashboard — Actual Results

Dataset: 600 customers, 4,252 transactions, synthetic but behaviorally realistic
(built with `generate_data.py` — five behavior archetypes: loyal, regular,
occasional, one-time, lapsed — so recency/frequency naturally vary, the way
real retail data does). Run `retail_analysis.py` to reproduce every number below.

## Headline metrics
- **Churn rate (>90 days inactive): 25.17%** | **Retention rate: 74.83%**
- Median recency across all customers: 40 days; 90th percentile: 227 days —
  this spread (and the elbow around 90 days) is *why* 90 days was chosen as
  the churn threshold, not an arbitrary round number.
- Total revenue across categories is nearly flat (₹3.55M–₹3.82M each across
  6 categories) — category mix is **not** a churn driver here; customer-level
  behavior is.

## Segment summary (RFM: Recency/Frequency/Monetary, quintile-scored)

| Segment   | # Customers | % Customers | Revenue (₹) | % Revenue | Avg Recency (days) |
|-----------|------------:|------------:|------------:|----------:|--------------------:|
| Champions | 135         | 22.5%       | 12,255,003  | 55.4%     | 13.9 |
| Loyal     | 118         | 19.7%       | 4,709,875   | 21.3%     | 33.2 |
| At Risk   | 171         | 28.5%       | 3,988,234   | 18.0%     | 101.7 |
| Lost      | 176         | 29.3%       | 1,186,951   | 5.4%      | 142.0 |

**Revenue concentration:** the top 15% of customers by spend generate
**44.5%** of total revenue — classic Pareto skew, worth stating plainly if
asked "is revenue concentrated?"

## The specific, defensible recommendation
**119 customers (19.8% of the base) sit in the 45–90 day "at-risk" window** —
not yet past the churn threshold, but trending that way — and they represent
**₹1,802,342** in historical spend. That's the group a win-back campaign
(targeted email/discount) should target *first*, because:
1. They're still reachable (haven't fully churned).
2. They've already proven they'll spend meaningfully (real historical value).
3. Waiting until they cross 90 days means reactivation is measurably harder
   (Lost-segment average recency is 142 days — over 4× the at-risk window).

## Honest caveats to state if pressed
- This is a synthetic dataset generated to have realistic behavior spread,
  not live company data — say so if asked directly.
- The 90-day threshold is a judgment call justified by the recency
  distribution, not a "correct" universal number — a different business
  (e.g. weekly-purchase grocery vs. annual big-ticket electronics) would need
  a different window.
- RFM quintile boundaries shift if the customer base changes — this
  segmentation should be re-run periodically, not treated as static labels.
