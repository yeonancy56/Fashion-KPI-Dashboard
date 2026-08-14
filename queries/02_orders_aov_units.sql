-- KPI 2 — Orders, Average Order Value, Units per Order
-- Question: How many orders were placed, and what does a typical order look like?
-- Note: COUNT(DISTINCT transaction_id) throughout — one order with four line
--       items is ONE order. COUNT(*) would inflate the denominator.

-- Orders
SELECT COUNT(DISTINCT transaction_id) AS orders
FROM sales;

-- Average order value
-- ROUND() wraps the whole division, not SUM(), so precision isn't lost first.
SELECT ROUND(SUM(line_total) / COUNT(DISTINCT transaction_id), 2) AS average_order_value
FROM sales;

-- Units per order
-- 1.0 * forces decimal division; both operands are integers otherwise.
SELECT ROUND(1.0 * SUM(quantity) / COUNT(DISTINCT transaction_id), 2) AS unit_per_order
FROM sales;
