# 👗 Fashion Retail KPI Analysis

<img src="images/banner.png" width="500" alt="banner">

***

## 📚 Table of Contents

- [Business Task](#business-task)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Question and Solution](#question-and-solution)
- [Insights](#insights)

***

## Business Task

*[2–3 sentences: who the brand is, what decision they need to make, and what's at stake. Write it like a stakeholder handed you the problem.]*

The dataset covers orders, products, and customers for a fashion retail business. *[Note where the data came from — synthetic, generated, exported.]*

***

## Entity Relationship Diagram

<img src="images/erd.png" alt="ERD">

| Object | What it holds |
| --- | --- |
| `transactions` | every line item, including returns (`returned` flag) |
| `sales` | a **view** over `transactions` with returns excluded — the base for all revenue KPIs |
| `products` | `product_id`, `product_name`, `category`, `unit_cost`, `units_received` |
| `customers` | `customer_id`, `country` |

Returns shouldn't count as revenue, but they *are* the thing you measure for return rate. Splitting them into a view and a base table means every revenue query reads from `sales` and never has to remember to filter, while the return-rate query reads from `transactions` and sees the full picture.

Schema and seed data are in [`data/schema.sql`](data/schema.sql) so anyone can rebuild the database and run every query below.

***

## Question and Solution

Queries are written in **DuckDB SQL**. One query uses `strftime()`, which is DuckDB-specific — the PostgreSQL equivalent is noted inline.

If you have any questions, reach out to me on [LinkedIn](YOUR_LINKEDIN_URL).

**1. What is the total revenue?**

```sql
SELECT ROUND(SUM(line_total), 2) AS total_sales
FROM sales;
```

**Steps:**

- Query the `sales` view rather than `transactions`, since the view already excludes returned items — no `WHERE` clause is needed.
- Use **SUM()** on `line_total` to collapse every line item into a single total, and wrap it in **ROUND()** with 2 decimal places to return a clean currency figure.

#### Answer:

| total_sales |
| ----------- |
| 582,222.00  |

- The business generated approximately **$582K** in net revenue over the period covered.

***

**2. How many orders were placed, and what does a typical order look like?**

```sql
-- Orders
SELECT COUNT(DISTINCT transaction_id) AS orders
FROM sales;

-- Average order value
SELECT ROUND(SUM(line_total) / COUNT(DISTINCT transaction_id), 2) AS average_order_value
FROM sales;

-- Units per order
SELECT ROUND(1.0 * SUM(quantity) / COUNT(DISTINCT transaction_id), 2) AS unit_per_order
FROM sales;
```

**Steps:**

- Use **COUNT(DISTINCT transaction_id)** in all three queries. One order containing four line items must count as a single order — `COUNT(*)` would count it four times and deflate the average order value accordingly.
- For average order value, divide total revenue by order count, then apply **ROUND()** to the result of the division rather than to `SUM(line_total)`, so precision isn't lost before the division happens.
- For units per order, multiply by **1.0** to force decimal division. `SUM(quantity)` and `COUNT(DISTINCT transaction_id)` are both integers, and integer division would floor 1.43 down to 1.

#### Answer:

| metric              | value   |
| ------------------- | ------- |
| Orders              | 5,084   |
| Average order value | $114.50 |
| Units per order     | 1.4     |

- Most orders consist of a single higher-priced item rather than a multi-item basket.
- Raising units per order from 1.4 to 1.7 would lift revenue without acquiring a single new customer, making bundling and free-shipping thresholds the clearest untapped lever.

***

**3. How does revenue trend month over month?**

```sql
SELECT
  strftime(order_date, '%Y-%m') AS month,
  ROUND(SUM(line_total), 2)     AS revenue
FROM sales
GROUP BY month
ORDER BY month;
```

**Steps:**

- Use **strftime()** to truncate each `order_date` down to its year and month, which turns dozens of individual dates into a single bucket per month.
- Format as `'%Y-%m'` rather than `'%m-%Y'` so the result (`2025-11`) sorts chronologically as plain text — `ORDER BY month` then works with no date casting.
- **GROUP BY** the `month` alias to aggregate revenue within each bucket. DuckDB permits referencing a `SELECT` alias here; PostgreSQL does not, and would need the full expression or `GROUP BY 1`.

Porting note: `strftime()` doesn't exist in PostgreSQL — use `TO_CHAR(order_date, 'YYYY-MM')` instead. SQLite has `strftime()` but takes the arguments in the reverse order: `strftime('%Y-%m', order_date)`.

#### Answer:

| month   | revenue  |
| ------- | --------- |
| 2025-07 | 46,540.98 |
| 2025-08 | 49,898.50 |
| 2025-09 | 44,367.56 |
| 2025-10 | 52,632.32 |
| 2025-11 | 35,261.30 |
| 2025-12 | 52,413.82 |
| 2026-01 | 56,197.08 |
| 2026-02 | 42,094.65 |
| 2026-03 | 55,341.05 |
| 2026-04 | 50,787.91 |
| 2026-05 | 48,083.03 |
| 2026-06 | 48,503.13 |

- Revenue holds steadily in the **$45K–$56K** range across most months.
- Revenue drops sharply to roughly **$35K in Nov 2025**, then rebounds to about **$55K in Dec** and peaks near **$56K in Mar 2026**.
- The November dip is the single clearest anomaly in the trend and warrants investigation — a stock-out and a seasonal lull call for very different responses.

***

**4. Which product categories drive revenue?**

```sql
SELECT
  p.category,
  ROUND(SUM(t.line_total), 2) AS revenue,
  SUM(t.quantity)             AS units
FROM sales t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;
```

**Steps:**

- Use **JOIN** to merge `sales` and `products`, since `category` lives on the products table while `line_total` lives on sales — neither table can answer this question alone.
- Return **revenue and units side by side**. A category can be high-revenue and low-unit (a few expensive items) or the reverse, and the two figures tell different merchandising stories.
- **GROUP BY** category and **ORDER BY** revenue descending so the categories carrying the business appear first.

#### Answer:

| category    | revenue    |
| ----------- | ---------- |
| Outerwear   | 152,153.00 |
| Footwear    | 137,546.00 |
| Accessories | ~56,000.00 |
| Tops        | ~46,000.00 |

- Outerwear and Footwear together account for roughly **49% of total revenue**.
- That concentration is a genuine risk — growing Tops or Accessories would diversify a top-heavy mix.

***

**5. Which products generate the most revenue?**

```sql
SELECT
  p.product_name,
  p.category,
  SUM(t.quantity)             AS units_sold,
  ROUND(SUM(t.line_total), 2) AS revenue
FROM sales t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;
```

**Steps:**

- Include `category` in the **GROUP BY** clause even though it isn't aggregated. Every non-aggregated column in `SELECT` must appear in `GROUP BY`, because SQL needs a guarantee the value is uniform across the group before it will display it.
- Apply **LIMIT 10** after **ORDER BY**. Ordering runs first in the execution sequence, so this returns the genuine top ten rather than ten arbitrary rows.

#### Answer:

| product_name   | category  | units_sold | revenue   |
| -------------- | --------- | ---------- | --------- |
| Puffer Jacket  | Outerwear | 223        | 38,167.30 |
| Heeled Sandals | Footwear  | 325        | 36,023.38 |
| Blazer         | Outerwear | 163        | 31,911.44 |
| Ankle Boots    | Footwear  | 302        | 29,175.97 |
| Parka          | Outerwear | 209        | 28,743.65 |
| Sneakers       | Footwear  | 300        | 28,376.33 |
| Slip Dress     | Dresses   | 312        | 27,432.15 |
| Trench Coat    | Outerwear | 193        | 26,793.36 |
| Wool Coat      | Outerwear | 171        | 26,536.91 |
| Loafers        | Footwear  | 260        | 25,391.02 |

- The top ten products are tightly bunched between **$25K and $38K**, led by the Puffer Jacket.
- No single hit product is carrying the business. That's healthy from a risk standpoint, but it also means there's no obvious style to double down on.

***

**6. What is the sell-through rate for each product?**

Sell-through rate = units sold ÷ units received × 100. It's the signature fashion KPI: it tells you whether the buy was right.

```sql
SELECT
  p.product_name,
  p.category,
  p.units_received,
  SUM(t.quantity)                                      AS units_sold,
  ROUND(100.0 * SUM(t.quantity) / p.units_received, 1) AS sell_through_pct
FROM products p
JOIN sales t ON t.product_id = p.product_id
GROUP BY p.product_name, p.category, p.units_received
ORDER BY sell_through_pct DESC;
```

**Steps:**

- Include `units_received` in the **GROUP BY** clause because it's displayed and not aggregated. It's constant per product, so grouping on it changes nothing about the result.
- Aggregate the numerator with **SUM()** but leave the denominator alone — `units_received` is already a single value per product, so summing it would multiply it by the number of rows in the group.
- Multiply by **100.0** rather than `100` to force decimal division; integer division would floor nearly every rate to 0.

A known limitation: `JOIN` here is an inner join, so any product that received inventory and sold **zero** units never appears in the results — and those are exactly the styles a merchandiser most needs to see. Switching to `LEFT JOIN products → sales` with `COALESCE(SUM(t.quantity), 0)` would surface them.

#### Answer:

| product_name | category | units_received | units_sold | sell_through_pct |
| ------------ | -------- | -------------- | ---------- | ---------------- |
| ...          | ...      | ...            | ...        | ...              |

- Footwear clears fastest across the category.
- Outerwear is slowest at roughly **55%**, despite being the number one revenue category — a strong signal the seasonal buy was over-weighted toward it rather than that demand was genuinely stronger.

***

**7. What is the gross margin by category?**

```sql
SELECT
  p.category,
  ROUND(SUM(t.line_total), 2)                            AS revenue,
  ROUND(SUM(t.line_total - t.quantity * p.unit_cost), 2) AS gross_margin_dollars,
  ROUND(
    100.0 * SUM(t.line_total - t.quantity * p.unit_cost)
    / SUM(t.line_total), 1
  )                                                      AS margin_pct
FROM sales t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY margin_pct DESC;
```

**Steps:**

- Calculate cost of goods sold as `t.quantity * p.unit_cost`. Cost is stored per-unit on the products table, so it has to be multiplied by the units actually sold on each line.
- Perform the subtraction **inside** the `SUM()`, at the row level, before aggregating. Summing revenue and cost separately then subtracting gives the same dollar figure here, but the row-level form is what you'd need the moment a per-line discount enters the data.
- **ORDER BY** `margin_pct` rather than `gross_margin_dollars`, which deliberately answers a different question: not "which category makes the most money" (that's question 4) but "which category is most efficient."

#### Answer:

| category    | revenue    | gross_margin_dollars | margin_pct |
| ----------- | ---------- | -------------------- | ---------- |
| Footwear    | 137,545.83 | 75,722.94            | 55.1       |
| Dresses     | 109,269.90 | 59,095.61            | 54.1       |
| Outerwear   | 152,152.66 | 82,011.68            | 53.9       |
| Accessories | 56,154.77  | 29,999.24            | 53.4       |
| Denim       | 81,353.17  | 43,031.93            | 52.9       |
| Tops        | 45,645.00  | 24,039.59            | 52.7       |

- *[Note the gap between the highest-revenue category and the highest-margin one — that gap is the entire reason this query exists.]*

***

**8. What is the return rate by category?**

```sql
SELECT
  p.category,
  ROUND(100.0 * SUM(CASE WHEN t.returned = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
    AS return_rate_pct
FROM transactions t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;
```

**Steps:**

- Query **`transactions`, not the `sales` view.** This is the one question where returns are the subject rather than the exclusion — running it against `sales` would report 0% for every category. Valid SQL, completely wrong answer.
- Use **SUM(CASE WHEN … THEN 1 ELSE 0 END)** to count rows meeting a condition. The `CASE` converts each row into a 1 or 0 and `SUM()` totals them, giving the count of returned line items.
- Divide by **COUNT(\*)**, which counts line items — so this is a *line-level* return rate. An order-level rate would use `COUNT(DISTINCT transaction_id)` and produce a different number, so it's worth stating which one you mean.

#### Answer:

| category    | return_rate_pct |
| ----------- | --------------- |
| Outerwear   | 18.7            |
| Denim       | 18.5            |
| Footwear    | 17.2            |

- Return rates cluster in a narrow **16–19%** band across every category.
- No single category is an outlier, which suggests returns here are a structural cost of doing business rather than a product-quality problem in one area.

***

**9. What share of customers ordered more than once?**

```sql
SELECT
  ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
    AS repeat_purchase_pct
FROM (
  SELECT
    customer_id,
    COUNT(DISTINCT t.transaction_id) AS order_count
  FROM sales t
  GROUP BY customer_id
) AS per_customer;
```

**Steps:**

- Build a **subquery** named `per_customer` that collapses `sales` down to one row per customer with their order count. This can't be done in a single pass, because the condition being tested (more than one order) is about a customer's aggregate, and `WHERE` runs before aggregation exists.
- Use **COUNT(DISTINCT t.transaction_id)** inside the subquery so a customer with one four-item order counts as one order — otherwise nearly everyone would look like a repeat buyer.
- In the outer query, use **SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)** for the count of repeat customers and **COUNT(\*)** for all customers; the ratio between them is the rate.
- Multiply by **100.0** rather than `100`. Two integers divided is integer division, and the decimal disappears silently.

#### Answer:

| repeat_purchase_pct |
| ------------------- |
| 98.0                |

- **880 of 898 customers** placed more than one order, averaging 5.7 orders each.
- A 98% repeat rate would be extraordinary for real retail. It's correct for this dataset because the synthetic customer base is small and dense — 898 customers across 5,084 orders. Flagging that here is more useful than leaving a reader to wonder.

***

**10. Where are customers buying from?**

```sql
SELECT
  c.country,
  COUNT(DISTINCT t.customer_id) AS customers,
  ROUND(SUM(t.line_total), 2)   AS revenue
FROM sales t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.country
ORDER BY revenue DESC;
```

**Steps:**

- Use **JOIN** to bring in `country` from the customers table, which sales doesn't carry.
- Return **customers and revenue together**, which makes it possible to spot markets that are large by headcount but small by spend, or the reverse — each implies a different growth play.
- Use **COUNT(DISTINCT t.customer_id)** to count people rather than line items.

#### Answer:

| country        | customers | revenue    |
| -------------- | --------- | ---------- |
| United Kingdom | 281       | 183,736.40 |
| United States  | 211       | 131,650.08 |
| Germany        | 107       | 70,083.05  |
| France         | 86        | 58,484.24  |
| Canada         | 77        | 52,401.56  |
| Australia      | 63        | 40,716.99  |
| Netherlands    | 38        | 23,188.71  |
| Sweden         | 35        | 21,860.30  |

- The **US and UK** are the largest markets by revenue.
- Smaller footprints elsewhere suggest room to expand rather than markets that have been tested and failed.

***

## Insights

- **Revenue is concentrated.** Outerwear and Footwear account for roughly 49% of $582K. Growing Tops or Accessories would diversify a top-heavy mix.
- **The top revenue category has the worst sell-through.** Outerwear leads on revenue but clears slowest at ~55%, pointing to an over-weighted seasonal buy rather than genuine demand strength.
- **Baskets are thin.** 1.4 items per order against a $114.50 average order value means most customers buy a single item — the clearest untapped lever in the dataset.
- **November underperformed by about 35%** against peak months, and the cause is worth identifying before the next cycle repeats it.
- **Returns are stable.** A tight 16–19% band across all categories means returns are a structural cost here, not a product-quality flag.

**Recommendation:** rebalance the Outerwear buy against its sell-through, test "complete the look" bundles against the 1.4-item basket, and diagnose the November gap before planning the next season's calendar.

***

## What I'd Do Next

*[One short paragraph — for example, adding a `LEFT JOIN` to surface zero-sale styles, layering in ad spend for ROAS and CAC, or automating the CSV export step. Optional, but it shows you think past the assignment.]*
