-- KPI 8 — Return Rate by Category
-- Question: What is the return rate by category?
-- IMPORTANT: reads from `transactions`, NOT the `sales` view. The view filters
--            returns out, so running this against it returns 0% for every
--            category — valid SQL, wrong answer.
-- Note: COUNT(*) counts line items, so this is a LINE-LEVEL return rate.
--       An order-level rate would use COUNT(DISTINCT transaction_id).

SELECT
  p.category,
  ROUND(100.0 * SUM(CASE WHEN t.returned = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
    AS return_rate_pct
FROM transactions t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;
