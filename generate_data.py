import numpy as np, pandas as pd
rng = np.random.default_rng(42)

N_CUSTOMERS = 600
categories = ['Grocery','Electronics','Apparel','Home & Kitchen','Beauty','Sports']
cities = ['Ludhiana','Chandigarh','Delhi','Amritsar','Jalandhar']

# customers with a signup date over the last 24 months
start = pd.Timestamp('2024-07-01')
end = pd.Timestamp('2026-07-31')
signup_days = rng.integers(0, (end-start).days, N_CUSTOMERS)
customers = pd.DataFrame({
    'customer_id': range(1, N_CUSTOMERS+1),
    'signup_date': [start + pd.Timedelta(days=int(d)) for d in signup_days],
    'city': rng.choice(cities, N_CUSTOMERS),
    'age_group': rng.choice(['18-25','26-35','36-45','46-60'], N_CUSTOMERS, p=[0.3,0.35,0.2,0.15])
})

# Give each customer a "behavior type" that drives how many transactions & recency they have
behavior = rng.choice(['loyal','regular','occasional','one_time','lapsed'], N_CUSTOMERS, p=[0.12,0.28,0.30,0.15,0.15])
customers['behavior'] = behavior

rows = []
txn_id = 1
snapshot = pd.Timestamp('2026-07-31')
for _, c in customers.iterrows():
    b = c['behavior']
    signup = c['signup_date']
    max_days_active = (snapshot - signup).days
    if b == 'loyal':
        n_txn = rng.integers(15, 35)
        last_gap = rng.integers(1, 20)   # still recently active
    elif b == 'regular':
        n_txn = rng.integers(6, 14)
        last_gap = rng.integers(5, 45)
    elif b == 'occasional':
        n_txn = rng.integers(2, 6)
        last_gap = rng.integers(20, 90)
    elif b == 'one_time':
        n_txn = 1
        last_gap = rng.integers(30, 400)
    else: # lapsed
        n_txn = rng.integers(3, 10)
        last_gap = rng.integers(120, 400)

    last_gap = min(last_gap, max_days_active) if max_days_active > 0 else 0
    last_purchase = snapshot - pd.Timedelta(days=int(last_gap))
    # spread earlier purchases between signup and last_purchase
    if n_txn > 1 and (last_purchase - signup).days > 0:
        gaps = np.sort(rng.integers(0, (last_purchase-signup).days, n_txn-1))
        dates = [signup + pd.Timedelta(days=int(g)) for g in gaps] + [last_purchase]
    else:
        dates = [last_purchase]

    for d in dates:
        cat = rng.choice(categories)
        qty = rng.integers(1,5)
        price = round(rng.uniform(150, 4000), 2)
        rows.append((txn_id, c['customer_id'], cat, int(qty), price, d))
        txn_id += 1

transactions = pd.DataFrame(rows, columns=['transaction_id','customer_id','category','quantity','unit_price','transaction_date'])
customers_out = customers[['customer_id','signup_date','city','age_group']]

customers_out.to_csv('/home/claude/retail_project/customers.csv', index=False)
transactions.to_csv('/home/claude/retail_project/transactions.csv', index=False)
print(customers_out.shape, transactions.shape)
print(transactions.head())
