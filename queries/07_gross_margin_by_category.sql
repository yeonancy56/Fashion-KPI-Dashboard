-- KPI 7 — Gross Margin by Category
-- Question: What is the gross margin by category?
-- Note: unit_cost is per-unit, so COGS for a line is quantity * unit_cost.
--       The subtraction happens INSIDE SUM(), at row level — same result today,
--       but required the moment a per-line discount enters the data.
-- Note: sorted by margin_pct, not dollars — this answers "most efficient",
--       where KPI 4 answers "most revenue".

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
