-- KPI 6 — Sell-Through Rate
-- Question: What is the sell-through rate for each product?
-- Formula: units sold / units received * 100
-- CRITICAL: group by product_id, NOT product_name. This table has 197 SKUs
--           across only 30 style names (~6-7 SKUs per style, each with its own
--           inventory receipt). Grouping by name merges those SKUs' sales into
--           one numerator while counting a single SKU's inventory in the
--           denominator — that produced rates as high as 312% before the fix.
-- Note: units_received is already one value per SKU, so it is NOT summed —
--       summing it would multiply it by the row count in the group.
-- Limitation: INNER JOIN hides SKUs with zero sales. See the LEFT JOIN
--             variant below to surface them.

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


-- Variant: includes SKUs that received inventory but sold nothing.
-- SELECT
--   p.product_id,
--   p.product_name,
--   p.category,
--   p.units_received,
--   COALESCE(SUM(t.quantity), 0)                                      AS units_sold,
--   ROUND(100.0 * COALESCE(SUM(t.quantity), 0) / p.units_received, 1) AS sell_through_pct
-- FROM products p
-- LEFT JOIN sales t ON t.product_id = p.product_id
-- GROUP BY p.product_id, p.product_name, p.category, p.units_received
-- ORDER BY sell_through_pct ASC;
