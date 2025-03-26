-- Query 1: Get markets for 'Atliq Exclusive' in APAC region
SELECT market 
FROM gdb023.dim_customer 
WHERE customer = 'Atliq Exclusive' AND region = 'APAC'
GROUP BY market;

-- Query 2: Number of customers in each region
SELECT region, COUNT(DISTINCT customer_code) AS customer_count
FROM gdb023.dim_customer
GROUP BY region
ORDER BY customer_count DESC;

-- Query 3: Unique products count by segment
SELECT segment, COUNT(DISTINCT product) AS product_count
FROM gdb023.dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- Query 4: Segment with highest increase in unique products (2021 vs 2020)
SELECT segment,
       COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS product_count_2020,
       COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS product_count_2021,
       (COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) - 
        COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END)) AS difference
FROM gdb023.dim_product
GROUP BY segment
ORDER BY difference DESC;

-- Query 5: Products with highest and lowest manufacturing costs
SELECT product_code, product, manufacturing_cost
FROM gdb023.fact_manufacturing_cost
WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM gdb023.fact_manufacturing_cost)
   OR manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM gdb023.fact_manufacturing_cost);

-- Query 6: Top 5 customers with highest average pre-invoice discount in 2021 (India Market)
SELECT f.customer_code, d.customer, AVG(f.pre_invoice_discount_pct) AS average_discount_percentage
FROM gdb023.fact_pre_invoice_deductions AS f
JOIN gdb023.dim_customer AS d ON f.customer_code = d.customer_code
WHERE fiscal_year = 2021 AND market = 'India'
GROUP BY f.customer_code, d.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- Query 7: Gross Sales Amount Report for 'Atliq Exclusive' by Month
SELECT s.month, s.fiscal_year AS year, ROUND(SUM(s.sold_quantity * g.gross_price), 2) AS gross_sales_amount
FROM gdb023.fact_sales_monthly AS s
JOIN gdb023.fact_gross_price AS g ON s.product_code = g.product_code
JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY s.fiscal_year, s.month
ORDER BY s.fiscal_year, s.month;

-- Query 8: Total sold quantity per quarter in 2020
WITH QuarterData AS (
    SELECT 
        CASE 
            WHEN month IN (9,10,11) THEN 'Q1'
            WHEN month IN (12,1,2) THEN 'Q2'
            WHEN month IN (3,4,5) THEN 'Q3'
            WHEN month IN (6,7,8) THEN 'Q4'
        END AS Quarter,
        SUM(sold_quantity) AS total_sold_quantity
    FROM gdb023.fact_sales_monthly
    WHERE fiscal_year = 2020
    GROUP BY Quarter
)
SELECT * FROM QuarterData ORDER BY total_sold_quantity DESC;

-- Query 9: Sales contribution by channel in 2021
WITH SalesData AS (
    SELECT c.channel, 
           ROUND(SUM(s.sold_quantity * g.gross_price)/1000000, 2) AS gross_sales_mln
    FROM gdb023.fact_sales_monthly AS s
    JOIN gdb023.fact_gross_price AS g ON s.product_code = g.product_code
    JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
    WHERE s.fiscal_year = 2021
    GROUP BY c.channel
)
SELECT channel, gross_sales_mln, 
       ROUND((gross_sales_mln / SUM(gross_sales_mln) OVER()) * 100, 2) AS percentage
FROM SalesData
ORDER BY gross_sales_mln DESC;

-- Query 10: Top 3 products by total sold quantity in each division (2021)
WITH RankedProducts AS (
    SELECT d.division, f.product_code, d.product, SUM(f.sold_quantity) AS total_sold_quantity,
           RANK() OVER(PARTITION BY d.division ORDER BY SUM(f.sold_quantity) DESC) AS rank_order
    FROM gdb023.fact_sales_monthly AS f
    JOIN gdb023.dim_product AS d ON f.product_code = d.product_code
    WHERE f.fiscal_year = 2021
    GROUP BY d.division, f.product_code, d.product
)
SELECT * FROM RankedProducts WHERE rank_order <= 3;
