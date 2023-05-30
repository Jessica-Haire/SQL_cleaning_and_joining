
--  Initial exploration of the dataset (Table 1 - sales data)
SELECT (
    SELECT COUNT(*)
    FROM fact_sales
) AS row_count,
    *
FROM fact_sales
LIMIT 5;


--  Initial exploration of the dataset (Table 2 -- customer data)
SELECT (
    SELECT COUNT(*)
    FROM dim_customers
) AS row_count,
    *
FROM dim_customers 
LIMIT 5;


--  Initial exploration of the dataset (Table 3 - product data)
SELECT (
    SELECT COUNT(*)
    FROM dim_products 
) AS row_count,
    *
FROM dim_products 
LIMIT 5;


-- Initial exploration of the dataset (Table 4 - mapping)
SELECT (
    SELECT COUNT(*)
    FROM state_region_mapping_new
) AS row_count,
    *
FROM state_region_mapping_new
LIMIT 5;



-- Further EDA

-- Sales by Category
SELECT 
	dp.category, 
	ROUND(SUM(sales)::numeric, 0) AS sales
FROM 
	fact_sales 
	INNER JOIN dim_products dp USING("Stock Code")
GROUP BY category 
ORDER BY sales DESC;



-- Sales by month   
DROP VIEW IF EXISTS sales_by_month;
CREATE VIEW sales_by_month AS
SELECT 
	month,
    ROUND(sales::numeric, 0) AS sales, 
    ROUND(running_total::numeric, 0) AS running_total,
    ROUND(sales::numeric / (SELECT SUM(sales) FROM fact_sales)::numeric * 100, 2) || '%' AS percent_of_total
FROM 
	(
    SELECT 
    to_char(date_trunc('month', to_timestamp("Transaction Date", 'MM/DD/YYYY HH24:MI')), 'MM-YYYY') AS month,
    SUM(sales) AS sales, 
    SUM(SUM(sales)) OVER(ORDER BY to_char(date_trunc('month', to_timestamp("Transaction Date", 'MM/DD/YYYY HH24:MI')), 'MM-YYYY')) AS running_total
	FROM fact_sales 
    GROUP BY month) AS total_sales_subq
ORDER BY month;



-- View the views within the schema
SELECT 
	schemaname, viewname, definition
FROM 
	pg_views
WHERE 
	schemaname = 'public';



-- Top ten customers
SELECT 
	REPLACE(CAST("Customer ID" AS text), ',', '') AS "Customer ID", 
	ROUND(SUM(sales)::numeric, 0) AS sales, SUM(SUM(sales)) over() AS total
FROM 
	fact_sales
	INNER JOIN dim_customers dc using("Customer ID")
GROUP BY "Customer ID"
ORDER BY sales DESC
LIMIT 10;



-- Create a table using a query result
-- Best selling products

DROP TABLE IF EXISTS best_sellers;
CREATE TABLE best_sellers
	(
	description VARCHAR(255),
	sales NUMERIC
	);

INSERT INTO best_sellers
SELECT 
	"description", ROUND(SUM(sales)::numeric, 0) AS sales
FROM 
	fact_sales
GROUP BY description 
ORDER BY sales DESC
LIMIT 10;

	-- Test
SELECT *
FROM best_sellers;



-- Market Basket Analysis data (products bought together): 
-- Requested by the marketing department for planning promotions, cross-selling, upselling and product placement 

SELECT 
    mba_subq.product1,
    mba_subq.product1_description,
    mba_subq.product2,
    mba_subq.product2_description,
    mba_subq.frequency,
    RANK() OVER (ORDER BY mba_subq.frequency DESC) AS rank
FROM 
	(
    SELECT 
    fs1."Stock Code" AS product1,
    fs1.description AS product1_description,
    fs2."Stock Code" AS product2,
    fs2.description AS product2_description,
    COUNT(*) AS frequency
    FROM fact_sales fs1
    INNER JOIN fact_sales fs2 ON fs1."Invoice No" = fs2."Invoice No" 
    						  AND fs1."Stock Code" < fs2."Stock Code"
    GROUP BY fs1."Stock Code", fs1.description, fs2."Stock Code", fs2.description
    HAVING COUNT(*) > 1) AS mba_subq
ORDER BY mba_subq.frequency DESC;


-- Further stakeholder requests:
-- Management wants to open a new warehouse to reduce shipping costs and offer quantity discount promotions
-- Sales by region (Where are customers' products shipped to?)

WITH location_cte AS 
(
SELECT 
	DISTINCT region, 
	"Order State"
FROM 
	state_region_mapping_new
)
SELECT 
	COALESCE(location_cte.region, 'In Person') AS region, 
	SUM(sales)::INTEGER AS revenue, 
	SUM(SUM(sales)::INTEGER) OVER() AS total_revenue --test 
    FROM 
    dim_customers dc 
	RIGHT JOIN fact_sales fs1 ON fs1."Customer ID" = dc."Customer ID"
	LEFT JOIN location_cte ON dc."Order State" = location_cte."Order State"
GROUP BY region
ORDER BY revenue DESC;

	-- Test 1a (duplication test -- ensure tables joined correctly -- how many rows are there?) 
SELECT COUNT(*)
FROM dim_customers  
RIGHT JOIN fact_sales
USING("Customer ID")

	--Test 1b (confirm number of rows)
SELECT COUNT(*)
FROM fact_sales;

	-- Test 2 (Confirm total revenue figure)
SELECT SUM(sales)::INTEGER
FROM fact_sales 



-- Sales by state 
SELECT ROUND(SUM(sales)::numeric, 0) AS sales,
states_subq.states,
SUM(ROUND(SUM(sales)::numeric, 0)) OVER () AS total
  FROM fact_sales fs1
LEFT JOIN (
SELECT 
    CAST(REPLACE(CAST(dc."Customer ID" AS text), ',', '') AS integer) AS "Customer ID",
    -- cleaning the Order State column
    CASE UPPER(dc."Order State")
      WHEN 'PUERTO RICO' THEN 'PR'
      WHEN 'PUERTO  RICO' THEN 'PR'
      WHEN 'TEXAS' THEN 'TX'
      WHEN 'WASHINGTON' THEN 'WA'
      WHEN 'WISCONSIN' THEN 'WI'
      WHEN 'WEST VIRGINIA' THEN 'WV'
      WHEN 'VIRGINIA' THEN 'VA'
      WHEN 'VERMONT' THEN 'VT'
      WHEN 'UTAH' THEN 'UT'
      WHEN 'TENNESSEE' THEN 'TN'
      WHEN 'SOUTH CAROLINA' THEN 'SC'
      WHEN 'PENNSYLVANIA' THEN 'PA'
      WHEN 'NORTH CAROLINA' THEN 'NC'
      WHEN 'NEW YORK' THEN 'NY'
      WHEN 'WYOMING' THEN 'WY'
      WHEN 'SOUTH DAKOTA' THEN 'SD'
      WHEN 'RHODE ISLAND' THEN 'RI'
      WHEN 'OREGON' THEN 'OR'
      WHEN 'MONTANA' THEN 'MT'
      WHEN 'OKLAHOMA' THEN 'OK'
      WHEN 'OHIO' THEN 'OH'
      WHEN 'NEW MEXICO' THEN 'NM'
      WHEN 'NEW JERSEY' THEN 'NJ'
      WHEN 'NEVADA' THEN 'NV'
      WHEN 'NEBRASKA' THEN 'NE'
      WHEN 'MISSOURI' THEN 'MO'
      WHEN 'MINNESOTA' THEN 'MN'
      WHEN 'MASSACHUSETTS' THEN 'MA'
      WHEN 'MICHIGAN' THEN 'MI'
      WHEN 'MARYLAND' THEN 'MD'
      WHEN 'MAINE' THEN 'ME'
      WHEN 'LOUISIANA' THEN 'LA'
      WHEN 'FLORIDA' THEN 'FL'
      WHEN 'KENTUCKY' THEN 'KY'
      WHEN 'KANSAS' THEN 'KS'
      WHEN 'IOWA' THEN 'IA'
      WHEN 'NEW HAMPSHIRE' THEN 'NH'
      WHEN 'MISSISSIPPI' THEN 'MS'
      WHEN 'INDIANA' THEN 'IN'
      WHEN 'ALABAMA' THEN 'AL'
      WHEN 'ARKANSAS' THEN 'AR'
      WHEN 'ARIZONA' THEN 'AZ'
      WHEN 'ALASKA' THEN 'AK'
      WHEN 'ILLINOIS' THEN 'IL'
      WHEN 'IDAHO' THEN 'ID'
      WHEN 'HAWAII' THEN 'HI'
      WHEN 'GEORGIA' THEN 'GA'
      WHEN 'DELAWARE' THEN 'DE'
      WHEN 'DISTRICT OF COLUMBIA' THEN 'DC'
      WHEN 'CONNECTICUT' THEN 'CT'
      WHEN 'COLORADO' THEN 'CO'
      WHEN 'CALIFORNIA' THEN 'CA'
      ELSE UPPER(LTRIM(RTRIM(REPLACE(dc."Order State", '.', ''))))
     END AS states
   FROM dim_customers dc) AS states_subq
  ON fs1."Customer ID" = states_subq."Customer ID"
  GROUP BY states
  ORDER BY sales DESC;
  


-- Manual mapping Test for sales by state
SELECT 
	ROUND(SUM(sales)::numeric, 0) AS sales,
	srmn.state, 
	SUM(ROUND(SUM(sales)::numeric, 0)) OVER () AS total
	FROM 
    fact_sales
	LEFT JOIN dim_customers dc using("Customer ID")
	LEFT JOIN state_region_mapping_new srmn ON dc."Order State" = srmn."Order State" 
GROUP BY state
ORDER BY sales DESC;

      
 





