USE olist_db;

-- ============================================================================
-- 5 ANALYTICAL VIEWS FOR TABLEAU DASHBOARDS & PYTHON EDA
-- ============================================================================

-- View 1: Master Order-Item Analytical Denormalized View (Powers Tableau Executive & Category Dashboards)
CREATE OR REPLACE VIEW vw_order_items_master AS
SELECT 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    DATE(o.order_purchase_timestamp) AS order_date,
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS year_month_str,
    DAYNAME(o.order_purchase_timestamp) AS order_day_name,
    HOUR(o.order_purchase_timestamp) AS order_hour,
    o.actual_delivery_days,
    o.estimated_delivery_days,
    o.delivery_delay_days,
    o.is_late,
    oi.order_item_id,
    oi.product_id,
    ct.product_category_name_english AS category_english,
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    CASE WHEN c.customer_state = s.seller_state THEN 'Intra-State' ELSE 'Inter-State' END AS shipping_scope,
    oi.price,
    oi.freight_value,
    oi.total_item_value,
    rev.avg_review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN (
    SELECT order_id, ROUND(AVG(review_score), 2) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
) rev ON o.order_id = rev.order_id;

-- View 2: Monthly Executive KPI & MoM Growth Summary View
CREATE OR REPLACE VIEW vw_monthly_kpi_summary AS
WITH monthly_base AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS year_month_str,
        YEAR(o.order_purchase_timestamp) AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
        ROUND(SUM(oi.price), 2) AS product_revenue,
        ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
        ROUND(SUM(oi.total_item_value), 2) AS gross_revenue,
        ROUND(SUM(oi.total_item_value) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value,
        ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.actual_delivery_days END), 1) AS avg_delivery_days,
        ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.is_late END) * 100.0, 2) AS late_delivery_pct
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
)
SELECT 
    *,
    LAG(gross_revenue) OVER (ORDER BY year_month_str) AS prev_month_revenue,
    ROUND((gross_revenue - LAG(gross_revenue) OVER (ORDER BY year_month_str)) * 100.0 / NULLIF(LAG(gross_revenue) OVER (ORDER BY year_month_str), 0), 2) AS mom_revenue_growth_pct
FROM monthly_base;

-- View 3: Customer RFM & Lifetime Value Segmentation View (Unique Customer Level)
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH max_dt AS (
    SELECT MAX(order_purchase_timestamp) AS ref_date FROM orders
),
cust_base AS (
    SELECT 
        c.customer_unique_id,
        MAX(c.customer_state) AS customer_state,
        MAX(c.customer_city) AS customer_city,
        MIN(o.order_purchase_timestamp) AS first_purchase_date,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        DATEDIFF((SELECT ref_date FROM max_dt), MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.total_item_value), 2) AS monetary,
        ROUND(AVG(oi.total_item_value), 2) AS avg_item_spend
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT 
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        CASE WHEN frequency >= 3 THEN 5 WHEN frequency = 2 THEN 4 ELSE 2 END AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM cust_base
)
SELECT 
    *,
    CONCAT(r_score, f_score, m_score) AS rfm_code,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN f_score >= 4 THEN 'Loyal Repeaters'
        WHEN r_score >= 4 AND m_score >= 4 THEN 'Recent Big Spenders'
        WHEN r_score >= 4 THEN 'Promising New Buyers'
        WHEN r_score = 3 THEN 'Needs Attention'
        WHEN r_score = 2 AND m_score >= 4 THEN 'At Risk High-Value'
        ELSE 'Hibernating / Lost'
    END AS rfm_segment
FROM scored;

-- View 4: Seller Operational & Quality Scorecard View
CREATE OR REPLACE VIEW vw_seller_scorecard AS
SELECT 
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(oi.price), 2) AS total_product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_generated,
    ROUND(AVG(oi.price), 2) AS avg_item_price,
    ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.actual_delivery_days END), 1) AS avg_delivery_days,
    ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.is_late END) * 100.0, 2) AS late_delivery_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY s.seller_id, s.seller_city, s.seller_state;

-- View 5: Regional State Logistics, Revenue & Satisfaction View
CREATE OR REPLACE VIEW vw_state_logistics_performance AS
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.freight_value) * 100.0 / NULLIF(SUM(oi.price), 0), 2) AS freight_ratio_pct,
    ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.actual_delivery_days END), 1) AS avg_delivery_days,
    ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.estimated_delivery_days END), 1) AS avg_estimated_days,
    ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o.is_late END) * 100.0, 2) AS late_delivery_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state;