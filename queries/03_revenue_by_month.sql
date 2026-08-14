-- KPI 3 — Revenue by Month
-- Question: How does revenue trend month over month?
-- Dialect: strftime() is DuckDB. PostgreSQL: TO_CHAR(order_date, 'YYYY-MM')
--          SQLite: strftime('%Y-%m', order_date)  <- arguments reversed
-- Note: '%Y-%m' sorts chronologically as plain text, so no date casting needed.

SELECT
  strftime(order_date, '%Y-%m') AS month,
  ROUND(SUM(line_total), 2)     AS revenue
FROM sales
GROUP BY month
ORDER BY month;
