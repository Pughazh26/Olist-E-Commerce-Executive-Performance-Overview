USE olist_db;

DROP PROCEDURE IF EXISTS sp_get_state_category_performance;
DROP PROCEDURE IF EXISTS sp_get_customer_rfm_profile;
DROP PROCEDURE IF EXISTS sp_get_top_sellers_by_period;

DELIMITER //

CREATE PROCEDURE sp_get_state_category_performance(
    IN p_state CHAR(2),
    IN p_year INT,
    IN p_limit INT
)
BEGIN
    SELECT 
        customer_state,
        order_year,
        category_english,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(*) AS units_sold,
        ROUND(SUM(price), 2) AS product_revenue,
        ROUND(SUM(total_item_value), 2) AS gross_revenue,
        ROUND(AVG(actual_delivery_days), 1) AS avg_delivery_days,
        ROUND(AVG(is_late) * 100.0, 2) AS late_delivery_pct,
        ROUND(AVG(avg_review_score), 2) AS avg_rating
    FROM vw_order_items_master
    WHERE customer_state = p_state
      AND order_year = p_year
      AND order_status NOT IN ('canceled', 'unavailable')
    GROUP BY customer_state, order_year, category_english
    ORDER BY gross_revenue DESC
    LIMIT p_limit;
END //

CREATE PROCEDURE sp_get_customer_rfm_profile(
    IN p_customer_unique_id VARCHAR(32)
)
BEGIN
    SELECT 
        customer_unique_id,
        customer_city,
        customer_state,
        first_purchase_date,
        last_purchase_date,
        recency_days,
        frequency,
        monetary,
        rfm_code,
        rfm_segment
    FROM vw_customer_rfm
    WHERE customer_unique_id = p_customer_unique_id;
END //

CREATE PROCEDURE sp_get_top_sellers_by_period(
    IN p_year INT,
    IN p_min_orders INT,
    IN p_limit INT
)
BEGIN
    SELECT 
        seller_id,
        seller_city,
        seller_state,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(*) AS items_sold,
        ROUND(SUM(price), 2) AS product_revenue,
        ROUND(AVG(actual_delivery_days), 1) AS avg_delivery_days,
        ROUND(AVG(is_late) * 100.0, 2) AS late_delivery_pct,
        ROUND(AVG(avg_review_score), 2) AS avg_rating
    FROM vw_order_items_master
    WHERE order_year = p_year
      AND order_status = 'delivered'
    GROUP BY seller_id, seller_city, seller_state
    HAVING COUNT(DISTINCT order_id) >= p_min_orders
    ORDER BY product_revenue DESC
    LIMIT p_limit;
END //

DELIMITER ;