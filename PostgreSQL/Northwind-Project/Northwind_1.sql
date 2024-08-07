-- Preprocessing data, starting with a check for missing values in crucial fields.
SELECT COUNT(*) AS total_rows, COUNT(o.order_id) AS non_missing_values_in_column,
  (COUNT(*) - COUNT(o.order_id)) AS missing_values_in_column
FROM orders o;
-- 0 missing values in orders table for order_ids.


-- Duplicate records identification.
SELECT p.product_id, COUNT(*)
FROM products p 
GROUP BY p.product_id HAVING COUNT(*) > 1;
/* Since product_id is PK for the table, a successful query 
with no rows returned means there are no duplicates. */


-- Anomalies in Date field check.
SELECT MIN(o.order_date) AS earliest_date, MAX(o.order_date) AS latest_date
FROM orders o;
-- Quick assess of the time range of our data, which appears to be normal.

-- Numerical fields validation. (Checking for negative values that should only be positive):
SELECT COUNT(*) 
FROM order_details od 
WHERE od.unit_price < 0 OR od.quantity < 0;


-- Customer with most orders.
SELECT c.customer_id, COUNT(order_id) as order_count 
FROM customers c JOIN orders o ON c.customer_id = o.customer_id 
GROUP BY c.customer_id ORDER BY order_count DESC LIMIT 1;
-- Result is 'SAVEA' which is used in the next query.


-- List of orders for customer with most orders, including dates and total order amount.
SELECT c.contact_name,c.company_name,o.order_date, 
ROUND(SUM(od.unit_price * od.quantity * (1-od.discount))::numeric,2) AS total_order_amount
FROM customers c JOIN orders o ON c.customer_id = o.customer_id 
JOIN order_details od ON o.order_id = od.order_id
WHERE c.customer_id = 'SAVEA'
GROUP BY c.contact_name,c.company_name,o.order_date ORDER BY o.order_date;
/* It can be noted that this customer has been ordering for 2 years 
(which is also the range of the dataset), highlighting their loyalty. */


/* Temp table creation for repeated use of total revenue,
First attempt at creating temp table resulted in aggregated results 
and double counting hence the drop table command*/
DROP TABLE IF EXISTS temp_total_revenue;
CREATE TEMP TABLE temp_total_revenue AS
SELECT
  od.order_id,
  od.product_id,
  ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric, 2) AS total_revenue
FROM order_details od
GROUP BY od.order_id, od.product_id;


-- Total orders and sales by country.
SELECT
  o.ship_country,
  COUNT(DISTINCT o.order_id) AS total_orders,
  SUM(ttr.total_revenue) AS total_revenue
FROM orders o
JOIN temp_total_revenue ttr ON o.order_id = ttr.order_id
GROUP BY o.ship_country
ORDER BY total_orders DESC;
-- Germany and USA reign at the top of total orders and total revenue generated.


-- Top 5 products by total revenue including a reordering alarm.
SELECT
  p.product_id,
  p.product_name,
  p.quantity_per_unit,
  p.units_in_stock,
  p.reorder_level,
  SUM(ttr.total_revenue) AS total_revenue,
  CASE
    WHEN p.units_in_stock <= p.reorder_level THEN 'Yes'
    ELSE 'No'
  END AS needs_reorder
FROM products p
JOIN temp_total_revenue ttr ON p.product_id = ttr.product_id
GROUP BY p.product_id, p.product_name, p.quantity_per_unit, p.units_in_stock, p.reorder_level
ORDER BY total_revenue DESC
LIMIT 5;
/* 4 of the Top 5 selling products have 0 reorder_level indicating possible oversight
of the column */


/* Month-over-Month Sales Trends.
Starting with a simple CTE calculating total sales each month */
WITH monthly_sales AS (
  SELECT
	EXTRACT(YEAR FROM o.order_date) AS year,
	EXTRACT(MONTH FROM o.order_date) AS month,
	ROUND(SUM(od.unit_price * od.quantity * (1 - COALESCE(od.discount, 0)))::numeric, 2) AS total_revenue
	-- Coalesce is used here for potential null values on discount column
  FROM order_details od JOIN orders o ON od.order_id = o.order_id 
  GROUP BY 1,2 ORDER BY 1,2
), -- Fetching previous month's total sales using LAG function and (x-y)/y formula for growth_percentage
sales_trends AS (
  SELECT 
	year, month, total_revenue,
	LAG(total_revenue) OVER (ORDER BY year,month) AS previous_month_sales,
	ROUND(((total_revenue - LAG(total_revenue) OVER (ORDER BY year,month))
	  /
	  LAG(total_revenue) OVER (ORDER BY year,month)) * 100 ,2) as mom_growth_percentage
	FROM monthly_sales
) -- LAG function allows us to 'store' the previous' month total revenue and compare it with current month.
SELECT 
  year, month, total_revenue, previous_month_sales, mom_growth_percentage
FROM sales_trends ORDER BY year,month;
-- Most months had positive month-over-month growth percentage but last month it plummeted by an impactful -85%.

-- Window function that calculates running totals of sales amounts
SELECT o.customer_id, o.order_date, ttr.total_revenue,
  SUM(ttr.total_revenue) OVER (PARTITION BY customer_id ORDER BY order_date) AS running_total
FROM orders o JOIN temp_total_revenue ttr ON o.order_id = ttr.order_id 
ORDER BY customer_id, order_date;
/* We get a list where each row includes original sale information along the new column 
that shows cumulative total of sales for that customer up to (and including) that row */


/* We can make a cohort analysis by using date_trunc function to compare the month of customers' first purchase,
revealing the initial month that led to the highest subsequent order volume. */
WITH first_order AS(
  SELECT 
	customer_id,
	MIN(order_date) AS first_order_date
  FROM orders GROUP BY customer_id
),
cohort_analysis AS(
  SELECT
	DATE_TRUNC('month', fo.first_order_date) AS cohort,
	DATE_TRUNC('month', o.order_date) AS order_month,
	COUNT(DISTINCT order_id) AS total_orders
  FROM orders o JOIN first_order fo ON o.customer_id = fo.customer_id
  GROUP BY cohort, order_month ORDER BY cohort, order_month
)
SELECT cohort, order_month, total_orders
FROM cohort_analysis
ORDER BY total_orders DESC;
/* May be important to note that dataset beings in 01-07-1996 which also marks the peak of customer acquisition
and engagement, that means the start of data collection could coincide with the launch of new business initiatives.
Further analysis of patterns and strategies adopted during that period could contribute to sustained business success.*/