CREATE DATABASE new_project;

USE new_project;

SELECT * FROM calender_file 
LIMIT 10;

DESC calender_file;


ALTER TABLE calender_file
RENAME COLUMN `ï»¿Date` TO Date;

SET SQL_SAFE_UPDATES = 0;

UPDATE calender_file
SET Date = STR_TO_DATE(Date, '%d-%m-%Y');

ALTER TABLE calender_file
MODIFY Date Date;

SELECT * FROM sales
LIMIT 10;

DESC sales;

UPDATE sales
SET OrderDate = STR_TO_DATE(OrderDate, '%d-%m-%Y');

UPDATE sales
SET ShipDate = STR_TO_DATE(ShipDate, '%d-%m-%Y');

ALTER TABLE sales
MODIFY ShipDate Date;

ALTER TABLE sales
MODIFY OrderDate Date;

SELECT * FROM calender_file 
WHERE Date	IS NULL OR 
Year IS NULL OR
	Quarter IS NULL OR
	`Quarter(Q)` IS NULL OR
	`Quarter_&_Year` IS NULL OR
	Month IS NULL OR
	Month_Name IS NULL OR
	`Month_&_Year` IS NULL OR
	Week_of_Year IS NULL OR
	`Week_of_Year(W)` IS NULL OR
    Day_of_Week IS NULL OR
	Day_Name IS NULL;
    
   --  1. Year-over-Year (YoY) Sales & Profit Growth.
   
   SELECT c.Year, ROUND(SUM(s.Sales),2) AS total_sales,
				ROUND(SUM(s.Profit),2) AS total_profit
FROM sales s
JOIN calender_file c
ON s.OrderDate = c.Date
GROUP BY c.Year
ORDER BY c.Year;

-- 2. Seasonality (The Weekend Effect)

SELECT c.Day_Name, 	
		ROUND(SUM(s.Sales),2) AS total_sales,
        SUM(CASE WHEN s.Returned = 'Yes' THEN 1 ELSE 0 END) AS total_returns
FROM sales s
JOIN calender_file c
ON s.OrderDate = c.Date
GROUP BY c.Day_Name
ORDER BY total_sales DESC;

-- 3. The Best Quarter

SELECT c.Year ,
	  c.`Quarter(Q)`,
      ROUND(SUM(s.sales),2) AS total_sales

FROM sales s
JOIN calender_file c
ON s.OrderDate = c.Date
GROUP BY c.Year ,
	  c.`Quarter(Q)`
ORDER BY total_sales DESC
LIMIT 1;

-- 4. The Discount Trap

SELECT Category, `Sub-Category`,
		ROUND(SUM(Sales),2) AS total_sales,
        ROUND(AVG(Discount) * 100, 2) AS avg_Discount_pct,
        ROUND(SUM(Profit),2) AS total_profit
FROM sales 
GROUP BY Category, `Sub-Category`
ORDER BY total_profit ASC;

-- 5. The Return Problem.

SELECT  Region, COUNT(*) AS total_orders,
		SUM(CASE WHEN Returned = 'Yes' THEN 1 ELSE 0 END) AS returned_orders,
        ROUND((SUM(CASE WHEN Returned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS return_rate_pct
FROM sales
GROUP BY Region
ORDER BY return_rate_pct DESC;

-- 6. Top 10 Loss-Making Customers

SELECT Customer_ID, Customer_Name,
		ROUND(SUM(sales),2) AS total_sales,
        ROUND(SUM(Profit),2) AS total_loss
FROM sales
GROUP BY Customer_ID, Customer_Name
HAVING total_loss < 0 
ORDER BY total_loss ASC
LIMIT 10;

-- 7. Shipping Delay Analysis

SELECT 
	Ship_Mode,
    ROUND(AVG(DATEDIFF(ShipDate,OrderDate)),2) AS avg_shipping_days
FROM sales
GROUP BY Ship_Mode
ORDER BY avg_shipping_days;

-- 8. Late Delivery Impact

WITH shippingdata AS (
		SELECT Order_ID, Returned,
        DATEDIFF(ShipDate, OrderDate) AS delivery_days
FROM sales )

SELECT 
	CASE WHEN delivery_days > 3 THEN 'Late ( > 3 Days)' 
    ELSE 'On Time  ( <= 3 Days)' END AS delivery_status,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Returned = 'yes' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND((SUM(CASE WHEN Returned = 'yes' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS return_rate_pct
FROM shippingdata
GROUP BY delivery_status;

-- 9. Salesperson Performance

SELECT 
    Retail_Sales_People,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS profit_margin_pct
FROM sales
GROUP BY Retail_Sales_People
ORDER BY total_sales DESC;

-- 10. The Pareto Principle (80/20 Rule)

WITH customers_sales AS (
    SELECT 
        Customer_ID,
        SUM(Sales) AS total_sales
    FROM sales
    GROUP BY Customer_ID
),

ranked_customer AS (
    SELECT 
        Customer_ID,
        total_sales,
        SUM(total_sales) OVER (ORDER BY total_sales DESC) AS running_total,
        (SELECT SUM(Sales) FROM sales) AS grand_total
    FROM customers_sales
)

SELECT 
    COUNT(Customer_ID) AS top_customer_count,
    
    (SELECT COUNT(DISTINCT Customer_ID) 
     FROM sales) AS total_customers,

    ROUND(
        (COUNT(Customer_ID) * 100.0) /
        (SELECT COUNT(DISTINCT Customer_ID) FROM sales),
        2
    ) AS pct_of_customers_generating_80_pct_sales

FROM ranked_customer
WHERE running_total <= grand_total * 0.80;

-- 11. Customer Churn

WITH customer_years AS (
		SELECT s.Customer_ID, c.Year
		  FROM sales s
		 JOIN calender_file c
			ON c.Date = s.OrderDate
			GROUP BY s.Customer_ID, c.Year
		     )    
         SELECT DISTINCT Customer_ID FROM Customer_Years
         WHERE Customer_ID IN ( SELECT Customer_ID FROM customer_years 
         WHERE YEAR IN (2025, 2016))
        AND Customer_ID NOT IN ( SELECT Customer_ID FROM customer_years 
		WHERE Year = 2017);
        
-- 12. 30-Day Moving Average

WITH daily_sales AS ( 
SELECT c.Date AS order_date,
		SUM(s.sales) AS daily_sales
		FROM sales s
        JOIN calender_file c
        ON c.Date = s.OrderDate
        GROUP BY order_date
        )
SELECT 
	order_date,
    daily_sales,
   ROUND(AVG(daily_sales) OVER(ORDER BY order_date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),2) AS 30_day_moving_avg
FROM daily_sales 
ORDER BY order_date;

-- 13. Customer Segmentation (Mini RFM)

SELECT Customer_ID,
			Customer_Name,
            COUNT(DISTINCT Order_ID ) AS total_orders,
            ROUND(SUM(sales),2) AS total_sales,
            CASE
				WHEN COUNT(DISTINCT Order_ID) = 1 then 'one_time_buyer'
                WHEN SUM(sales) > 2000 THEN 'VIP'
                ELSE 'REGULAR' END AS customer_segment
                FROM sales
                GROUP BY Customer_ID,
						Customer_Name
				ORDER BY total_sales DESC;
                
-- 14. Month-over-Month (MoM) Growth
WITH monthly_sales AS (
    SELECT 
        c.Year,
        c.Month,
        SUM(s.sales) AS current_month_sales
    FROM sales s
    JOIN calender_file c
        ON c.Date = s.OrderDate
    GROUP BY c.Year, c.Month
)

SELECT 
    Year,
    Month,

    ROUND(current_month_sales, 2) AS current_sales,

    ROUND(
        LAG(current_month_sales) OVER (ORDER BY Year, Month),
        2
    ) AS previous_month_sales,

    ROUND(
        (
            (current_month_sales - 
             LAG(current_month_sales) OVER (ORDER BY Year, Month))
            /
             LAG(current_month_sales) OVER (ORDER BY Year, Month)
        ) * 100,
        2
    ) AS mom_growth_pct

FROM monthly_sales;

-- 15. Most Profitable Route

SELECT 
	State, City,
    COUNT(Order_ID) AS total_orders,
    ROUND(SUM(Profit),2) AS total_profit,
    ROUND(SUM(Profit) / COUNT(Order_ID),2) AS profit_per_order
    FROM sales
    GROUP BY State, City
	HAVING total_orders > 10
    ORDER BY profit_per_order DESC
    LIMIT 5;
        
                
                

 





    
    
        

      
 







