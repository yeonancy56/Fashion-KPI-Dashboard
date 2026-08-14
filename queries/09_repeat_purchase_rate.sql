-- KPI 9 — Repeat Purchase Rate
-- Question: What share of customers ordered more than once?
-- Note: the subquery collapses sales to one row per customer. This can't be
--       done in a single pass — the condition (>1 order) is about an aggregate,
--       and WHERE runs before aggregation exists.
-- Note: 100.0 not 100 — integer division would silently drop the decimal.

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


-- Supporting check: the per-customer distribution behind the 98% figure.
-- Run this to confirm the rate is a property of the data (small, dense
-- customer base) rather than a bug.
SELECT
  customer_id,
  COUNT(DISTINCT t.transaction_id) AS order_count
FROM sales t
GROUP BY customer_id
ORDER BY order_count;
