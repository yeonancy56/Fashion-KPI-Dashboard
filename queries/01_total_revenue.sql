-- KPI 1 — Total Revenue
-- Question: What is the total revenue?
-- Note: reads from the `sales` view, which already excludes returned items.

SELECT ROUND(SUM(line_total), 2) AS total_sales
FROM sales;
