-- KPI 10 — Revenue by Country
-- Question: Where are customers buying from?
-- Note: returning customers alongside revenue distinguishes "many small
--       spenders" from "few large ones" — different growth plays.

SELECT
  c.country,
  COUNT(DISTINCT t.customer_id) AS customers,
  ROUND(SUM(t.line_total), 2)   AS revenue
FROM sales t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.country
ORDER BY revenue DESC;
