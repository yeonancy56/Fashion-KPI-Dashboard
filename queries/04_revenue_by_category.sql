-- KPI 4 — Revenue by Category
-- Question: Which product categories drive revenue?
-- Note: category lives on products, line_total lives on sales — the JOIN is
--       required. Returning units alongside revenue distinguishes "few
--       expensive items" from "many cheap items".

SELECT
  p.category,
  ROUND(SUM(t.line_total), 2) AS revenue,
  SUM(t.quantity)             AS units
FROM sales t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;
