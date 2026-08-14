-- ============================================================
-- Fashion Retail KPI Analysis — schema
-- Dialect: DuckDB
-- ============================================================
-- Adjust column types to match your actual data before committing.
-- The point of this file is reproducibility: anyone should be able to
-- run it, load the seed data, and execute every query in /queries.

DROP VIEW  IF EXISTS sales;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;


-- ------------------------------------------------------------
-- products
-- ------------------------------------------------------------
CREATE TABLE products (
  product_id     INTEGER PRIMARY KEY,
  product_name   VARCHAR,
  category       VARCHAR,
  unit_cost      DECIMAL(10,2),   -- per-unit cost, used for gross margin
  units_received INTEGER          -- inventory bought in, used for sell-through
);


-- ------------------------------------------------------------
-- customers
-- ------------------------------------------------------------
CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY,
  country     VARCHAR
);


-- ------------------------------------------------------------
-- transactions — every line item, INCLUDING returns
-- ------------------------------------------------------------
-- Grain: one row per product per order. A single transaction_id can
-- appear on several rows, which is why every order count in /queries
-- uses COUNT(DISTINCT transaction_id).
CREATE TABLE transactions (
  transaction_id INTEGER,
  customer_id    INTEGER,
  product_id     INTEGER,
  order_date     DATE,
  quantity       INTEGER,
  line_total     DECIMAL(10,2),
  returned       INTEGER,         -- 1 = returned, 0 = kept
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  FOREIGN KEY (product_id)  REFERENCES products(product_id)
);


-- ------------------------------------------------------------
-- sales — the revenue base: transactions with returns removed
-- ------------------------------------------------------------
-- Returns shouldn't count as revenue, but they ARE the thing measured
-- for return rate. Splitting them means every revenue query reads from
-- this view and never has to remember to filter, while
-- 08_return_rate_by_category.sql reads from `transactions` and sees the
-- full picture. One decision, made once, that keeps ten queries honest.
CREATE VIEW sales AS
SELECT *
FROM transactions
WHERE returned = 0;


-- ------------------------------------------------------------
-- Seed data
-- ------------------------------------------------------------
-- Option A — load from the CSVs in data/raw/ (DuckDB):
--   INSERT INTO products     SELECT * FROM read_csv_auto('data/raw/products.csv');
--   INSERT INTO customers    SELECT * FROM read_csv_auto('data/raw/customers.csv');
--   INSERT INTO transactions SELECT * FROM read_csv_auto('data/raw/transactions.csv');
--
-- Option B — paste INSERT statements below so the file is fully
-- self-contained and needs no external files. Better for a portfolio
-- repo if the dataset is small enough.

-- INSERT INTO products (product_id, product_name, category, unit_cost, units_received) VALUES
--   (1, '...', '...', 0.00, 0);
