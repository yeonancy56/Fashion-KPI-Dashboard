-- KPI 5 — Top 10 Products by Revenue
-- Question: Which products generate the most revenue?
-- Note: category must be in GROUP BY because it's selected and not aggregated.
--       LIMIT applies after ORDER BY, so this is the genuine top 10.

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
