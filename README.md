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

The dataset covers **twelve months of orders (July 2025 – June 2026)** for a fashion retail business: 5,084 orders, 7,009 units, $582,121 in net revenue, 898 customers, and 197 SKUs across 30 style names in six categories. *[Note where the data came from — synthetic, generated, exported.]*

***

## Entity Relationship Diagram

<img src="images/erd.png" alt="ERD">

| Object | What it holds |
| --- | --- |
| `transactions` | every line item, including returns (`returned` flag) |
| `sales` | a **view** over `transactions` with returns excluded — the base for all revenue KPIs |
| `products` | `product_id`, `product_name`, `category`, `unit_cost`, `units_received` — 197 rows across 30 style names |
| `customers` | `customer_id`, `country` |

Returns shouldn't count as revenue, but they *are* the thing you measure for return rate. Splitting them into a view and a base table means every revenue query reads from `sales` and never has to remember to filter, while the return-rate query reads from `transactions` and sees the full picture.

One property of `products` matters throughout: **`product_name` is not unique.** Each style name covers roughly 6–7 SKUs, each with its own inventory receipt. Question 6 shows what goes wrong when a query forgets that.

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
| 582,121.33  |

- The business generated **$582,121.33** in net revenue across the twelve-month period.
- This figure reconciles against both the category breakdown in question 4 and the country breakdown in question 10, which is a useful sign that neither join is duplicating or dropping rows.

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
- For units per order, multiply by **1.0** to force decimal division. `SUM(quantity)` and `COUNT(DISTINCT transaction_id)` are both integers, and integer division would floor 1.38 down to 1.

#### Answer:

| metric              | value   |
| ------------------- | ------- |
| Orders              | 5,084   |
| Average order value | $114.50 |
| Units per order     | 1.38    |

- Most orders consist of a single higher-priced item rather than a multi-item basket.
- Raising units per order from 1.38 to 1.7 would lift revenue without acquiring a single new customer, making bundling and free-shipping thresholds the clearest untapped lever in the dataset.

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
- Format as `'%Y-%m'` rather than `'%m-%Y'` so the result (`2025-11`) sorts chronologically as plain text — `ORDER BY month` then works with no date casting, even though the column comes back as VARCHAR.
- **GROUP BY** the `month` alias to aggregate revenue within each bucket. DuckDB permits referencing a `SELECT` alias here; PostgreSQL does not, and would need the full expression or `GROUP BY 1`.

Porting note: `strftime()` doesn't exist in PostgreSQL — use `TO_CHAR(order_date, 'YYYY-MM')` instead. SQLite has `strftime()` but takes the arguments in the reverse order: `strftime('%Y-%m', order_date)`.

#### Answer:

| month   | revenue   |
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

- Revenue averages **$48,510 a month**, with most months landing between $42K and $56K.
- **November 2025 is the clear outlier at $35,261** — 27% below the monthly average and the only month under $40K.
- **January 2026 is the strongest month at $56,197**, with March close behind at $55,341. December sits mid-pack at $52,414, which is worth noting for a fashion retailer: there is no pronounced holiday spike.
- The November trough followed by a December and January recovery is the pattern worth explaining. A stock-out and a seasonal lull look identical in this table but call for opposite responses, so the next step would be checking inventory positions for that month.

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

| category    | revenue    | units |
| ----------- | ---------- | ----- |
| Outerwear   | 152,152.66 | 959   |
| Footwear    | 137,545.83 | 1,369 |
| Dresses     | 109,269.90 | 1,297 |
| Denim       | 81,353.17  | 1,080 |
| Accessories | 56,154.77  | 1,246 |
| Tops        | 45,645.00  | 1,058 |

- Outerwear and Footwear together account for **49.8% of total revenue** ($289.7K of $582.1K) — real concentration risk.
- **Outerwear leads on revenue while selling the fewest units of any category.** The two columns pull in opposite directions, and the reason is price: revenue per unit runs $158.66 for Outerwear against $43.14 for Tops.

| category    | revenue per unit |
| ----------- | ---------------- |
| Outerwear   | $158.66          |
| Footwear    | $100.47          |
| Dresses     | $84.25           |
| Denim       | $75.33           |
| Accessories | $45.07           |
| Tops        | $43.14           |

- Unit volume is remarkably even — every category moves between 959 and 1,369 units. Revenue rank is therefore almost entirely a **price-point ranking**, not a demand ranking. Tops and Accessories aren't unpopular; they're cheap.

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
- Grouping by `product_name` here is deliberate and correct — this question asks about styles, so the 6–7 SKUs behind each name should roll up into one row. (Question 6 asks a different question and needs the opposite treatment.)
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

- The top ten are tightly bunched between **$25.4K and $38.2K**, led by the Puffer Jacket. No single hit product is carrying the business — healthy from a risk standpoint, but it means there is no obvious style to double down on.
- **Outerwear takes five of the ten slots and Footwear four**, with a single dress rounding out the list. The two concentrated categories from question 4 dominate here too.
- The two groups get there by opposite routes. Outerwear sells 163–223 units at **$137–$196 each**, while Footwear sells 260–325 units at **$95–$111 each**. Same revenue band, completely different mechanics — and therefore different levers if you wanted to grow either.

***
**6. What is the sell-through rate for each product?**

Sell-through rate = units sold ÷ units received × 100. It's the signature fashion KPI: it tells you whether the buy was right.

```sql
SELECT
  p.product_id,
  p.product_name,
  p.category,
  p.units_received,
  SUM(t.quantity)                                      AS units_sold,
  ROUND(100.0 * SUM(t.quantity) / p.units_received, 1) AS sell_through_pct
FROM products p
JOIN sales t ON t.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category, p.units_received
ORDER BY sell_through_pct DESC;
```

**Steps:**

- **GROUP BY `product_id`, not `product_name`.** This table holds 197 SKUs across only 30 style names — roughly 6–7 SKUs per style, each with its own inventory receipt. Grouping by name merges those SKUs' sales into one numerator while counting a single SKU's inventory in the denominator, which produced sell-through rates as high as 312% before the fix. `product_id` is the primary key, so grouping on it keeps numerator and denominator describing the same thing.
- Aggregate the numerator with **SUM()** but leave the denominator alone — `units_received` is already a single value per SKU, so summing it would multiply it by the row count in the group.
- Multiply by **100.0** rather than `100` to force decimal division; integer division would floor nearly every rate to 0.

A known limitation: `JOIN` here is an inner join, so any SKU that received inventory and sold **zero** units never appears in the results — and those are exactly the ones a merchandiser most needs to see. Switching to `LEFT JOIN products → sales` with `COALESCE(SUM(t.quantity), 0)` would surface them.

#### Answer:

197 rows. The ten highest:

| product_id | product_name   | category    | units_received | units_sold | sell_through_pct |
| ---------- | -------------- | ----------- | -------------- | ---------- | ---------------- |
| P0157      | Ballet Flats   | Footwear    | 40             | 56         | 140.0            |
| P0033      | Shirt Dress    | Dresses     | 40             | 49         | 122.5            |
| P0151      | Heeled Sandals | Footwear    | 40             | 44         | 110.0            |
| P0190      | Beanie         | Accessories | 40             | 43         | 107.5            |
| P0152      | Heeled Sandals | Footwear    | 40             | 43         | 107.5            |
| P0081      | Denim Jacket   | Denim       | 40             | 43         | 107.5            |
| P0024      | Slip Dress     | Dresses     | 60             | 63         | 105.0            |
| P0169      | Silk Scarf     | Accessories | 40             | 39         | 97.5             |
| P0008      | Maxi Dress     | Dresses     | 40             | 39         | 97.5             |
| P0054      | Knit Sweater   | Tops        | 40             | 39         | 97.5             |

The ten lowest:

| product_id | product_name  | category    | units_received | units_sold | sell_through_pct |
| ---------- | ------------- | ----------- | -------------- | ---------- | ---------------- |
| P0109      | Wool Coat     | Outerwear   | 200            | 34         | 17.0             |
| P0011      | Maxi Dress    | Dresses     | 200            | 34         | 17.0             |
| P0140      | Loafers       | Footwear    | 200            | 32         | 16.0             |
| P0108      | Puffer Jacket | Outerwear   | 150            | 24         | 16.0             |
| P0166      | Leather Belt  | Accessories | 200            | 31         | 15.5             |
| P0178      | Tote Bag      | Accessories | 200            | 30         | 15.0             |
| P0165      | Leather Belt  | Accessories | 200            | 29         | 14.5             |
| P0146      | Loafers       | Footwear    | 200            | 28         | 14.0             |
| P0035      | Shirt Dress   | Dresses     | 200            | 23         | 11.5             |
| P0049      | Silk Blouse   | Tops        | 200            | 18         | 9.0              |

- **Aggregate sell-through is 34.7%** — 7,009 units sold against 20,180 received. The median SKU sits at 38.0%.
- Read the `units_received` column down both tables and the pattern is unmissable: nearly every top performer received 40 units, and every bottom performer received 200. Grouping all 197 SKUs by buy depth confirms it:

| units received | SKUs | mean units sold | mean sell-through |
| -------------- | ---- | --------------- | ----------------- |
| 40             | 30   | 34.8            | 87.0%             |
| 60             | 28   | 37.2            | 62.0%             |
| 80             | 37   | 36.0            | 45.0%             |
| 100            | 28   | 34.9            | 34.9%             |
| 120            | 27   | 34.1            | 28.4%             |
| 150            | 22   | 36.8            | 24.6%             |
| 200            | 25   | 35.3            | 17.7%             |

- **Every SKU sells roughly 35 units no matter how deep it was bought.** Demand per SKU doesn't scale with the buy at all, so this ranking sorts by *buy depth*, not by product performance. The Silk Blouse at the bottom didn't sell badly — it sold 18 units after someone ordered 200 of it.
- That's worth naming plainly rather than dressing up as a merchandising finding: it's a property of how this dataset was generated, with sales assigned independently of inventory levels. Real data would show deeper buys on products that genuinely sell more. The same flatness produces the seven SKUs above 100% sell-through, which is physically impossible and confirms sales were never constrained by stock on hand.
- At category level the spread is correspondingly narrow — Dresses 36.3%, Outerwear 36.2%, Denim 35.9%, Tops 35.1%, Accessories 33.9%, Footwear 32.1% — which follows directly from flat per-SKU demand combined with differing SKU counts per category.

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

- Margin percentage is **remarkably flat**, spanning only 2.4 points from Tops (52.7%) to Footwear (55.1%). Blended gross margin across the business is 53.9% on $313,900 of margin dollars.
- **Footwear is the strongest category on both measures** — highest margin rate at 55.1% and second-highest revenue.
- **Outerwear generates the most margin dollars ($82,012)** despite ranking only third on rate, because volume more than compensates for the 1.2-point gap.
- That flatness is itself the finding. When every category converts revenue to margin at roughly the same rate, total profit is driven by **revenue mix, not margin mix** — so the merchandising decisions that matter are the ones in questions 4 and 5, not this one. There is no hidden high-margin category to lean into.

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
| Dresses     | 18.6            |
| Denim       | 18.5            |
| Footwear    | 18.4            |
| Accessories | 18.1            |
| Tops        | 15.6            |

- Return rates are **tightly clustered between 18.1% and 18.7%** for five of the six categories — a spread of just 0.6 points.
- **Tops is the lone exception at 15.6%**, roughly 2.5 points below every other category.
- The uniformity across the other five suggests returns here are a structural cost of doing business rather than a product-quality problem in any one area. Tops being the outlier is consistent with it also being the cheapest category ($43.14 per unit from question 4) — lower-priced items are less likely to be worth the effort of returning.
- Roughly **one line item in five comes back**, which is high enough to matter: at an 18.4% blended rate, returns are shaping the gap between gross and net revenue more than any single merchandising decision in this analysis.

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
- A 98% repeat rate would be extraordinary for real retail. It's correct for this dataset because the customer base is small and dense — 898 customers across 5,084 orders. Flagging that here is more useful than leaving a reader to wonder.

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

- The **United Kingdom is the largest market**, at $183.7K across 281 customers — ahead of the United States at $131.7K.
- Revenue per customer is remarkably flat across all eight countries, ranging only from **$610 (Netherlands) to $681 (Canada)**. Market size is therefore almost entirely a function of *how many customers* each country has, not how much they individually spend.
- That flatness reframes the growth question: the lever in smaller markets is customer acquisition, not basket size. A Swedish customer is worth about the same as a British one — there just aren't many of them yet.
- The eight countries sum to $582,121.33, reconciling with total revenue in question 1, and the customer counts sum to 898, matching the customer base in question 9.

***

## Insights

- **Revenue is concentrated.** Outerwear and Footwear account for 49.8% of $582,121. Growing Dresses or Denim would diversify a top-heavy mix.
- **Revenue rank is a price ranking, not a demand ranking.** Every category moves between 959 and 1,369 units, but revenue per unit spans $43 to $159. Tops and Accessories aren't unpopular — they're inexpensive.
- **Margin is uniform across the assortment.** Every category converts revenue to gross margin at 52.7–55.1%, so total profit is driven by revenue mix rather than margin mix. There is no hidden high-margin category to lean into.
- **Baskets are thin.** 1.38 items per order against a $114.50 average order value means most customers buy a single item — the clearest untapped lever in the dataset.
- **November 2025 underperformed badly** at $35,261, 27% below the monthly average and the only month under $40K. December showed no holiday spike either, which is unusual for fashion retail.
- **The UK, not the US, is the largest market**, and revenue per customer barely varies between countries ($610–$681). Geographic growth is an acquisition problem, not a spending-behavior one.
- **Returns are uniformly high.** Five of six categories fall within 0.6 points of each other (18.1–18.7%), with Tops the lone outlier at 15.6%. Roughly one line item in five comes back — a structural cost rather than a quality problem in any one category.
- **Sell-through tracks buy depth, not product appeal.** Every SKU sells about 35 units regardless of whether 40 or 200 were ordered, so the sell-through ranking sorts by how deep each buy was. That flatness is an artifact of how the dataset was generated, and it's flagged as such rather than presented as a merchandising finding.

**Recommendation:** test "complete the look" bundles against the 1.38-item basket, diagnose the November gap before planning the next season's calendar, and treat customer acquisition rather than basket growth as the lever in the smaller international markets.

***

## What I'd Do Next

*[One short paragraph — for example, adding a `LEFT JOIN` to surface SKUs with zero sales, layering in ad spend for ROAS and CAC, or automating the CSV export step. Optional, but it shows you think past the assignment.]*
