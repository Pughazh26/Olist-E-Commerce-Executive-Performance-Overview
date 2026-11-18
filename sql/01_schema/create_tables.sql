USE olist_db;

-- Drop child tables first if re-running
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS category_translation;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS geolocation;

-- 1. Geolocation Lookup Table
CREATE TABLE geolocation (
    geolocation_zip_code_prefix INT PRIMARY KEY,
    geolocation_lat DECIMAL(10, 8) NOT NULL,
    geolocation_lng DECIMAL(11, 8) NOT NULL,
    geolocation_city VARCHAR(100) NOT NULL,
    geolocation_state CHAR(2) NOT NULL,
    INDEX idx_geo_state (geolocation_state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix INT NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL,
    INDEX idx_customer_unique_id (customer_unique_id),
    INDEX idx_customer_state (customer_state),
    INDEX idx_customer_zip (customer_zip_code_prefix)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Sellers Table
CREATE TABLE sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix INT NOT NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL,
    INDEX idx_seller_state (seller_state),
    INDEX idx_seller_zip (seller_zip_code_prefix)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Product Category Translation Table
CREATE TABLE category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Products Table
CREATE TABLE products (
    product_id VARCHAR(32) PRIMARY KEY,
    product_category_name VARCHAR(100) NOT NULL,
    product_name_length INT NOT NULL,
    product_description_length INT NOT NULL,
    product_photos_qty INT NOT NULL,
    product_weight_g DECIMAL(10, 2) NOT NULL,
    product_length_cm DECIMAL(10, 2) NOT NULL,
    product_height_cm DECIMAL(10, 2) NOT NULL,
    product_width_cm DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_name) REFERENCES category_translation(product_category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Orders Table
CREATE TABLE orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NOT NULL,
    actual_delivery_days DECIMAL(8, 2) NULL,
    estimated_delivery_days DECIMAL(8, 2) NULL,
    delivery_delay_days DECIMAL(8, 2) NULL,
    is_late TINYINT NULL,
    INDEX idx_order_status (order_status),
    INDEX idx_purchase_ts (order_purchase_timestamp),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Order Items Table
CREATE TABLE order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    freight_value DECIMAL(10, 2) NOT NULL,
    total_item_value DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. Order Payments Table
CREATE TABLE order_payments (
    order_id VARCHAR(32) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    INDEX idx_payment_type (payment_type),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. Order Reviews Table (Composite PK because review_id repeats across multi-item orders)
CREATE TABLE order_reviews (
    review_id VARCHAR(32) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    review_score TINYINT NOT NULL,
    review_comment_title TEXT NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NOT NULL,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_review_score (review_score),
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;