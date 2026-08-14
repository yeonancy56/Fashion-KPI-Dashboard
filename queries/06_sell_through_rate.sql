-- KPI 6 — Sell-Through Rate
-- Question: What is the sell-through rate for each product?
-- Formula: units sold / units received * 100
-- Note: units_received is already one value per product, so it is NOT summed —
--       summing it would multiply it by the row count in the group.
-- Limitation: INNER JOIN hides products with zero sales. See the LEFT JOIN
--             variant below to surface them.

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


-- Variant: includes products that received inventory but sold nothing.
-- SELECT
--   p.product_name,
--   p.category,
--   p.units_received,
--   COALESCE(SUM(t.quantity), 0)                                      AS units_sold,
--   ROUND(100.0 * COALESCE(SUM(t.quantity), 0) / p.units_received, 1) AS sell_through_pct
-- FROM products p
-- LEFT JOIN sales t ON t.product_id = p.product_id
-- GROUP BY p.product_name, p.category, p.units_received
-- ORDER BY sell_through_pct ASC;
