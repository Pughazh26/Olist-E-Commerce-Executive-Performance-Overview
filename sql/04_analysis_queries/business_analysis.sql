USE olist_db;

-- ============================================================================
-- BATCH 1: EXECUTIVE SALES, REVENUE TRENDS & ORDER FUNNEL (QUERIES 1 - 10)
-- ============================================================================

-- Q1: Executive KPI Summary (Total Orders, Delivered Orders, Customers, GMV, Freight, AOV)
SELECT 
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN o.order_id END) AS delivered_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price), 2) AS total_product_gmv,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_revenue,
    ROUND(SUM(oi.total_item_value), 2) AS total_gross_revenue,
    ROUND(SUM(oi.total_item_value) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id;

-- Q2: Order Status Funnel & Cancellation / Unavailability Rate
SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_total_orders
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- Q3: Yearly Revenue, Orders, & Average Order Value (YoY Comparison)
SELECT 
    YEAR(o.order_purchase_timestamp) AS order_year,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS active_customers,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.total_item_value), 2) AS total_revenue,
    ROUND(SUM(oi.total_item_value) / COUNT(DISTINCT o.order_id), 2) AS aov
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY YEAR(o.order_purchase_timestamp)
ORDER BY order_year;

-- Q4: Monthly Revenue Trend with Month-over-Month (MoM) Growth % & Running Cumulative Total
WITH monthly_sales AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS year_month_str,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(oi.total_item_value), 2) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT 
    year_month_str,
    total_orders,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY year_month_str) AS prev_month_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year_month_str)) * 100.0 /
        NULLIF(LAG(monthly_revenue) OVER (ORDER BY year_month_str), 0), 2
    ) AS mom_growth_pct,
    ROUND(SUM(monthly_revenue) OVER (ORDER BY year_month_str), 2) AS cumulative_revenue
FROM monthly_sales
ORDER BY year_month_str;

-- Q5: Quarterly Revenue & Order Volume Breakdown
SELECT 
    YEAR(o.order_purchase_timestamp) AS order_year,
    QUARTER(o.order_purchase_timestamp) AS order_quarter,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.total_item_value), 2) AS quarterly_revenue,
    ROUND(AVG(oi.total_item_value), 2) AS avg_item_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY YEAR(o.order_purchase_timestamp), QUARTER(o.order_purchase_timestamp)
ORDER BY order_year, order_quarter;

-- Q6: Day-of-Week Shopping Pattern (Orders, Revenue & Share %)
SELECT 
    DAYNAME(o.order_purchase_timestamp) AS day_of_week,
    DAYOFWEEK(o.order_purchase_timestamp) AS day_num,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.total_item_value), 2) AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / SUM(COUNT(DISTINCT o.order_id)) OVER(), 2) AS order_share_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY DAYNAME(o.order_purchase_timestamp), DAYOFWEEK(o.order_purchase_timestamp)
ORDER BY day_num;

-- Q7: Peak Shopping Hours (Time-of-Day Segmentation)
SELECT 
    CASE 
        WHEN HOUR(o.order_purchase_timestamp) BETWEEN 6 AND 11 THEN 'Morning (06-11)'
        WHEN HOUR(o.order_purchase_timestamp) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN HOUR(o.order_purchase_timestamp) BETWEEN 18 AND 23 THEN 'Evening (18-23)'
        ELSE 'Late Night (00-05)'
    END AS time_bucket,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.total_item_value), 2) AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / SUM(COUNT(DISTINCT o.order_id)) OVER(), 2) AS pct_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY time_bucket
ORDER BY total_orders DESC;

-- Q8: Top 10 Single Highest-Revenue Days (e.g., Black Friday Spike Detection)
SELECT 
    DATE(o.order_purchase_timestamp) AS order_date,
    DAYNAME(o.order_purchase_timestamp) AS day_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.total_item_value), 2) AS daily_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY DATE(o.order_purchase_timestamp), DAYNAME(o.order_purchase_timestamp)
ORDER BY daily_revenue DESC
LIMIT 10;

-- Q9: Multi-Item Basket Size Distribution (Items per Order vs Revenue)
WITH order_basket AS (
    SELECT 
        order_id,
        COUNT(order_item_id) AS items_in_order,
        SUM(price) AS order_product_value,
        SUM(freight_value) AS order_freight_value
    FROM order_items
    GROUP BY order_id
)
SELECT 
    CASE 
        WHEN items_in_order = 1 THEN '1 Item'
        WHEN items_in_order = 2 THEN '2 Items'
        WHEN items_in_order = 3 THEN '3 Items'
        ELSE '4+ Items'
    END AS basket_size,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_orders,
    ROUND(AVG(order_product_value), 2) AS avg_product_spend,
    ROUND(AVG(order_freight_value), 2) AS avg_freight_cost
FROM order_basket
GROUP BY basket_size
ORDER BY order_count DESC;

-- Q10: Payment Value vs Order Item Value Reconciliation Check
WITH item_totals AS (
    SELECT order_id, ROUND(SUM(total_item_value), 2) AS expected_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, ROUND(SUM(payment_value), 2) AS paid_total
    FROM order_payments
    GROUP BY order_id
)
SELECT 
    COUNT(*) AS matched_orders,
    SUM(CASE WHEN ABS(i.expected_total - p.paid_total) <= 0.05 THEN 1 ELSE 0 END) AS exact_match_orders,
    SUM(CASE WHEN ABS(i.expected_total - p.paid_total) > 0.05 THEN 1 ELSE 0 END) AS discrepancy_orders,
    ROUND(SUM(p.paid_total) - SUM(i.expected_total), 2) AS net_payment_diff
FROM item_totals i
JOIN payment_totals p ON i.order_id = p.order_id;
-- ============================================================================
-- BATCH 2: CUSTOMER RETENTION, COHORTS & RFM SEGMENTATION (QUERIES 11 - 20)
-- ============================================================================

-- Q11: One-Time vs Repeat Customers Breakdown (Using customer_unique_id)
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(oi.total_item_value), 2) AS total_spend
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT 
    CASE 
        WHEN order_count = 1 THEN '1 Order (One-Time)'
        WHEN order_count = 2 THEN '2 Orders (Repeat)'
        ELSE '3+ Orders (Loyal)'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_customers,
    ROUND(SUM(total_spend), 2) AS segment_revenue,
    ROUND(SUM(total_spend) * 100.0 / SUM(SUM(total_spend)) OVER(), 2) AS pct_revenue,
    ROUND(AVG(total_spend), 2) AS avg_clv
FROM customer_orders
GROUP BY customer_type
ORDER BY customer_count DESC;

-- Q12: Top 15 Highest-Value Repeat Customers (Lifetime Value Leaders)
SELECT 
    c.customer_unique_id,
    MAX(c.customer_state) AS state,
    MAX(c.customer_city) AS city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.total_item_value), 2) AS lifetime_spend,
    ROUND(AVG(oi.total_item_value), 2) AS avg_item_spend,
    MIN(DATE(o.order_purchase_timestamp)) AS first_order_date,
    MAX(DATE(o.order_purchase_timestamp)) AS last_order_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) >= 2
ORDER BY lifetime_spend DESC
LIMIT 15;

-- Q13: Average Time Gap (Days) Between 1st and 2nd Order for Repeat Buyers
WITH ranked_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp
        ) AS order_seq
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
)
SELECT 
    COUNT(*) AS repeat_buyers_analyzed,
    ROUND(AVG(DATEDIFF(o2.order_purchase_timestamp, o1.order_purchase_timestamp)), 1) AS avg_days_to_second_order,
    MIN(DATEDIFF(o2.order_purchase_timestamp, o1.order_purchase_timestamp)) AS min_days_gap,
    MAX(DATEDIFF(o2.order_purchase_timestamp, o1.order_purchase_timestamp)) AS max_days_gap
FROM ranked_orders o1
JOIN ranked_orders o2 
    ON o1.customer_unique_id = o2.customer_unique_id
    AND o1.order_seq = 1 
    AND o2.order_seq = 2;

-- Q14: Monthly Customer Acquisition (New Unique Customers per Month)
WITH first_purchase AS (
    SELECT 
        c.customer_unique_id,
        DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m') AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT 
    cohort_month,
    COUNT(customer_unique_id) AS new_customers_acquired,
    SUM(COUNT(customer_unique_id)) OVER (ORDER BY cohort_month) AS cumulative_customers
FROM first_purchase
GROUP BY cohort_month
ORDER BY cohort_month;

-- Q15: Monthly Cohort Retention Matrix (Months 0 to 5 Retention %)
WITH customer_cohort AS (
    SELECT 
        c.customer_unique_id,
        DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m-01') AS cohort_date
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
cohort_activity AS (
    SELECT 
        cc.cohort_date,
        TIMESTAMPDIFF(
            MONTH, 
            cc.cohort_date, 
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')
        ) AS month_index,
        COUNT(DISTINCT cc.customer_unique_id) AS active_users
    FROM customer_cohort cc
    JOIN customers c ON cc.customer_unique_id = c.customer_unique_id
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY cc.cohort_date, month_index
)
SELECT 
    DATE_FORMAT(cohort_date, '%Y-%m') AS cohort_month,
    MAX(CASE WHEN month_index = 0 THEN active_users END) AS m0_users,
    ROUND(MAX(CASE WHEN month_index = 1 THEN active_users END) * 100.0 / NULLIF(MAX(CASE WHEN month_index = 0 THEN active_users END), 0), 2) AS m1_ret_pct,
    ROUND(MAX(CASE WHEN month_index = 2 THEN active_users END) * 100.0 / NULLIF(MAX(CASE WHEN month_index = 0 THEN active_users END), 0), 2) AS m2_ret_pct,
    ROUND(MAX(CASE WHEN month_index = 3 THEN active_users END) * 100.0 / NULLIF(MAX(CASE WHEN month_index = 0 THEN active_users END), 0), 2) AS m3_ret_pct,
    ROUND(MAX(CASE WHEN month_index = 4 THEN active_users END) * 100.0 / NULLIF(MAX(CASE WHEN month_index = 0 THEN active_users END), 0), 2) AS m4_ret_pct
FROM cohort_activity
WHERE cohort_date BETWEEN '2017-01-01' AND '2018-04-01'
GROUP BY cohort_date
ORDER BY cohort_date;

-- Q16: SQL RFM Scoring & Customer Segmentation (Champions, Loyal, At Risk, Hibernating)
WITH dataset_max_date AS (
    SELECT MAX(order_purchase_timestamp) AS max_ts FROM orders
),
rfm_raw AS (
    SELECT 
        c.customer_unique_id,
        DATEDIFF((SELECT max_ts FROM dataset_max_date), MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.total_item_value), 2) AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        CASE 
            WHEN frequency >= 3 THEN 5
            WHEN frequency = 2 THEN 4
            ELSE 2
        END AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_raw
),
rfm_segmented AS (
    SELECT 
        *,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN f_score >= 4 THEN 'Loyal Repeaters'
            WHEN r_score >= 4 AND m_score >= 4 THEN 'Recent Big Spenders'
            WHEN r_score >= 4 THEN 'Promising New Buyers'
            WHEN r_score = 3 THEN 'Needs Attention'
            WHEN r_score = 2 AND m_score >= 4 THEN 'At Risk High-Value'
            ELSE 'Hibernating / Lost'
        END AS rfm_segment
    FROM rfm_scores
)
SELECT 
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_customers,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    ROUND(SUM(monetary), 2) AS total_segment_revenue
FROM rfm_segmented
GROUP BY rfm_segment
ORDER BY total_segment_revenue DESC;

-- Q17: Repeat Purchase Rate by Customer State (Top 10 States by Customer Volume)
WITH state_cust AS (
    SELECT 
        c.customer_state,
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_placed
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_state, c.customer_unique_id
)
SELECT 
    customer_state,
    COUNT(*) AS unique_customers,
    SUM(CASE WHEN orders_placed > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN orders_placed > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_rate_pct
FROM state_cust
GROUP BY customer_state
ORDER BY unique_customers DESC
LIMIT 10;

-- Q18: First-Order Category That Drives Highest Repeat Purchases
WITH ordered_cust_cats AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        ct.product_category_name_english AS category,
        DENSE_RANK() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp ASC
        ) AS purchase_num
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
cust_total_orders AS (
    SELECT customer_unique_id, MAX(purchase_num) AS max_orders
    FROM ordered_cust_cats
    GROUP BY customer_unique_id
)
SELECT 
    f.category AS first_purchase_category,
    COUNT(DISTINCT f.customer_unique_id) AS acquired_customers,
    COUNT(DISTINCT CASE WHEN t.max_orders > 1 THEN f.customer_unique_id END) AS repeat_buyers,
    ROUND(
        COUNT(DISTINCT CASE WHEN t.max_orders > 1 THEN f.customer_unique_id END) * 100.0 /
        COUNT(DISTINCT f.customer_unique_id), 2
    ) AS repeat_conversion_pct
FROM ordered_cust_cats f
JOIN cust_total_orders t ON f.customer_unique_id = t.customer_unique_id
WHERE f.purchase_num = 1
GROUP BY f.category
HAVING COUNT(DISTINCT f.customer_unique_id) >= 500
ORDER BY repeat_conversion_pct DESC
LIMIT 10;

-- Q19: Impact of First-Order Delivery Delay on Repeat Purchase Rate
WITH cust_orders_ranked AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.is_late,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp ASC
        ) AS rn,
        COUNT(*) OVER (PARTITION BY c.customer_unique_id) AS total_orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND o.is_late IS NOT NULL
)
SELECT 
    CASE WHEN is_late = 1 THEN '1st Order Late' ELSE '1st Order On-Time' END AS first_delivery_experience,
    COUNT(*) AS customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS returned_for_2nd_order,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_rate_pct
FROM cust_orders_ranked
WHERE rn = 1
GROUP BY first_delivery_experience;

-- Q20: Customer Spending Deciles (Pareto / 80-20 Revenue Concentration Check)
WITH cust_spend AS (
    SELECT 
        c.customer_unique_id,
        SUM(oi.total_item_value) AS total_spend,
        NTILE(10) OVER (ORDER BY SUM(oi.total_item_value) DESC) AS spend_decile
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT 
    spend_decile,
    COUNT(*) AS customers_in_decile,
    ROUND(MIN(total_spend), 2) AS min_spend,
    ROUND(MAX(total_spend), 2) AS max_spend,
    ROUND(SUM(total_spend), 2) AS decile_revenue,
    ROUND(SUM(total_spend) * 100.0 / SUM(SUM(total_spend)) OVER(), 2) AS pct_of_total_revenue
FROM cust_spend
GROUP BY spend_decile
ORDER BY spend_decile;
-- ============================================================================
-- BATCH 3: PRODUCTS, SELLERS, GEOGRAPHY, PAYMENTS & LOGISTICS (QUERIES 21 - 30)
-- ============================================================================

-- Q21: Top 15 Product Categories by Revenue, Units Sold & Revenue Share %
SELECT 
    ct.product_category_name_english AS category_english,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS units_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.total_item_value), 2) AS gross_revenue,
    ROUND(AVG(oi.price), 2) AS avg_unit_price,
    ROUND(SUM(oi.total_item_value) * 100.0 / SUM(SUM(oi.total_item_value)) OVER(), 2) AS revenue_share_pct
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY ct.product_category_name_english
ORDER BY gross_revenue DESC
LIMIT 15;

-- Q22: Bottom 10 Product Categories by Revenue (Long-Tail / Underperforming Categories)
SELECT 
    ct.product_category_name_english AS category_english,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS units_sold,
    ROUND(SUM(oi.total_item_value), 2) AS gross_revenue,
    ROUND(AVG(oi.price), 2) AS avg_unit_price
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY ct.product_category_name_english
ORDER BY gross_revenue ASC
LIMIT 10;

-- Q23: Top 3 Highest-Revenue Products Within Each of the Top 5 Categories (Window DENSE_RANK)
WITH top_categories AS (
    SELECT p.product_category_name
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_category_name
    ORDER BY SUM(oi.total_item_value) DESC
    LIMIT 5
),
ranked_products AS (
    SELECT 
        ct.product_category_name_english AS category_english,
        oi.product_id,
        COUNT(*) AS units_sold,
        ROUND(SUM(oi.total_item_value), 2) AS product_revenue,
        DENSE_RANK() OVER (
            PARTITION BY ct.product_category_name_english 
            ORDER BY SUM(oi.total_item_value) DESC
        ) AS category_rank
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND p.product_category_name IN (SELECT product_category_name FROM top_categories)
    GROUP BY ct.product_category_name_english, oi.product_id
)
SELECT *
FROM ranked_products
WHERE category_rank <= 3
ORDER BY category_english, category_rank;

-- Q24: Category Satisfaction vs Delivery Delay (Min 100 Reviewed Orders)
SELECT 
    ct.product_category_name_english AS category_english,
    COUNT(DISTINCT o.order_id) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(AVG(o.actual_delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(o.is_late) * 100.0, 2) AS late_delivery_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.actual_delivery_days IS NOT NULL
GROUP BY ct.product_category_name_english
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY avg_review_score ASC
LIMIT 15;

-- Q25: Top 15 Sellers Performance Scorecard (Revenue, Orders, Late Rate & Avg Rating)
SELECT 
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS seller_product_revenue,
    ROUND(AVG(o.is_late) * 100.0, 2) AS late_delivery_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state, s.seller_city
HAVING COUNT(DISTINCT oi.order_id) >= 50
ORDER BY seller_product_revenue DESC
LIMIT 15;

-- Q26: Seller Pareto Concentration (Top 10% Sellers Share of Total Marketplace GMV)
WITH seller_rev AS (
    SELECT 
        oi.seller_id,
        SUM(oi.price) AS product_gmv,
        NTILE(10) OVER (ORDER BY SUM(oi.price) DESC) AS seller_decile
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY oi.seller_id
)
SELECT 
    seller_decile,
    COUNT(*) AS seller_count,
    ROUND(SUM(product_gmv), 2) AS decile_gmv,
    ROUND(SUM(product_gmv) * 100.0 / SUM(SUM(product_gmv)) OVER(), 2) AS gmv_share_pct
FROM seller_rev
GROUP BY seller_decile
ORDER BY seller_decile;

-- Q27: Regional Performance by Customer State (Revenue, Freight Ratio, Delivery Speed & Rating)
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.freight_value) * 100.0 / NULLIF(SUM(oi.price), 0), 2) AS freight_to_price_pct,
    ROUND(AVG(o.actual_delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(o.is_late) * 100.0, 2) AS late_rate_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY product_revenue DESC;

-- Q28: Intra-State vs Inter-State Shipping Impact (Same State vs Cross State Logistics)
SELECT 
    CASE 
        WHEN c.customer_state = s.seller_state THEN 'Intra-State (Same State)'
        ELSE 'Inter-State (Cross State)'
    END AS shipping_scope,
    COUNT(*) AS item_shipments,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_cost,
    ROUND(AVG(o.actual_delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(o.is_late) * 100.0, 2) AS late_delivery_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.actual_delivery_days IS NOT NULL
GROUP BY shipping_scope;

-- Q29: Payment Method Adoption, Installments & Average Transaction Value
SELECT 
    payment_type,
    COUNT(DISTINCT order_id) AS orders_count,
    COUNT(*) AS payment_rows,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS payment_share_pct,
    ROUND(AVG(payment_installments), 1) AS avg_installments,
    ROUND(MAX(payment_installments), 0) AS max_installments,
    ROUND(AVG(payment_value), 2) AS avg_payment_value,
    ROUND(SUM(payment_value), 2) AS total_payment_volume
FROM order_payments
WHERE payment_type <> 'not_defined'
GROUP BY payment_type
ORDER BY total_payment_volume DESC;

-- Q30: Delivery Timeliness vs Customer Review Score (On-Time vs Late Delay Buckets)
SELECT 
    CASE 
        WHEN o.delivery_delay_days <= -5 THEN '1. Early (5+ Days Early)'
        WHEN o.delivery_delay_days <= 0 THEN '2. On-Time (0 to 4 Days Early)'
        WHEN o.delivery_delay_days BETWEEN 1 AND 3 THEN '3. Slightly Late (1-3 Days)'
        WHEN o.delivery_delay_days BETWEEN 4 AND 7 THEN '4. Moderately Late (4-7 Days)'
        ELSE '5. Severely Late (8+ Days)'
    END AS delivery_timeliness_bucket,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / SUM(COUNT(DISTINCT o.order_id)) OVER(), 2) AS pct_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS one_star_pct
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.delivery_delay_days IS NOT NULL
GROUP BY delivery_timeliness_bucket
ORDER BY delivery_timeliness_bucket;