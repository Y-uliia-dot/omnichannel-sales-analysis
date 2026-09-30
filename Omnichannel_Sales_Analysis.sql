-- Omnichannel Sales Analysis
-- SQL coursework project | IT School GoIT
--
-- Analyzes customer spending, product popularity, and purchasing activity
-- across online and offline retail channels.
--
-- Original query logic is preserved; only section headings were clarified.
-- Requires the original coursework database and its tables.
-- Execute queries separately in a compatible SQL environment.

-- Query 1: Total online spending by customer.
SELECT
    o.user_id,
    SUM(oi.quantity * p.product_price) AS total_spent
FROM orders_sql_project o
LEFT JOIN order_items_sql_project oi
    ON o.order_id = oi.order_id
LEFT JOIN products_sql_project p
    ON oi.product_id = p.product_id
GROUP BY o.user_id
ORDER BY total_spent DESC;

-- Query 2: Combined chronological list of identified online and offline buyers.
SELECT
    user_id,
    order_date,
    store_order_id AS order_id
FROM store_orders
WHERE user_id IS NOT NULL

UNION ALL

SELECT
    user_id,
    order_date,
    order_id
FROM orders_sql_project
WHERE user_id IS NOT NULL

ORDER BY user_id, order_date, order_id;

-- Query 3: Products purchased through both sales channels.
select product_id
from order_items_sql_project

intersect 

select product_id
from store_order_items
order by product_id;


-- Query 4: Customers who purchased more than two units in each channel.
SELECT user_id
FROM orders_sql_project
WHERE user_id IS NOT NULL
AND order_id IN (
    SELECT order_id
    FROM order_items_sql_project
    WHERE quantity > 2
)

INTERSECT

SELECT user_id
FROM store_orders
WHERE user_id IS NOT NULL
AND store_order_id IN (
    SELECT store_order_id
    FROM store_order_items
    WHERE quantity > 2
)

ORDER BY user_id;

-- Query 5: Average order value for paid online orders.
SELECT 
    AVG(total_check) AS avg_check
FROM (
    SELECT 
        o.order_id,
        SUM(oi.quantity * p.product_price) AS total_check
    FROM orders_sql_project o
    LEFT JOIN order_items_sql_project oi
        ON o.order_id = oi.order_id
    LEFT JOIN products_sql_project p
        ON oi.product_id = p.product_id
    LEFT JOIN payments_sql_project pay
        ON o.order_id = pay.order_id
    WHERE pay.payment_status = 'Оплачено'
    GROUP BY o.order_id
) order_check;

-- Query 6: Total units sold and distinct order counts by sales channel.
WITH products_quantity_stores AS (
    SELECT 
        order_id,
        product_id,
        quantity,
        'online' AS store_type
    FROM order_items_sql_project

    UNION ALL  

    SELECT
        store_order_id AS order_id,
        product_id,
        quantity,
        'offline' AS store_type
    FROM store_order_items
)
SELECT
    store_type,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT order_id) AS total_orders
FROM products_quantity_stores
GROUP BY store_type
ORDER BY store_type ASC, total_quantity ASC, total_orders ASC;

-- Query 7: Three products purchased by the highest number of distinct customers across channels.
WITH users_products AS (
    SELECT
        o.user_id,
        oi.product_id
    FROM orders_sql_project o
    LEFT JOIN order_items_sql_project oi
        ON o.order_id = oi.order_id

    UNION ALL

    SELECT
        so.user_id,
        soi.product_id
    FROM store_orders so
    LEFT JOIN store_order_items soi
        ON so.store_order_id = soi.store_order_id
)
SELECT
    product_id,
    COUNT(DISTINCT user_id) AS users_count
FROM users_products
WHERE user_id IS NOT NULL
GROUP BY product_id
ORDER BY users_count DESC
LIMIT 3;

-- Query 8: Comparison of average order values between online and offline sales.
SELECT
    AVG(total_check) AS avg_check,
    shop_type
FROM (
    SELECT
        o.order_id,
        SUM(oi.quantity * p.product_price) AS total_check,
        'online' AS shop_type
    FROM orders_sql_project o
    LEFT JOIN order_items_sql_project oi
        ON o.order_id = oi.order_id
    LEFT JOIN products_sql_project p
        ON oi.product_id = p.product_id
    GROUP BY o.order_id

    UNION ALL

    SELECT
        so.store_order_id AS order_id,
        SUM(soi.quantity * p.product_price) AS total_check,
        'offline' AS shop_type
    FROM store_orders so
    LEFT JOIN store_order_items soi
        ON so.store_order_id = soi.store_order_id
    LEFT JOIN products_sql_project p
        ON soi.product_id = p.product_id
    GROUP BY so.store_order_id
) checks
GROUP BY shop_type
ORDER BY avg_check;

-- Query 9: Online customers who bought a product priced above the average price of products sold offline.
WITH all_orders AS (
    SELECT
        o.user_id,
        oi.product_id
    FROM orders_sql_project o
    LEFT JOIN order_items_sql_project oi
        ON o.order_id = oi.order_id
)
SELECT DISTINCT
    a.user_id
FROM all_orders a
LEFT JOIN products_sql_project p
    ON a.product_id = p.product_id
WHERE p.product_price > (
    SELECT
        AVG(p2.product_price) AS avg_product_price
    FROM products_sql_project p2
    WHERE p2.product_id IN (
        SELECT
            soi.product_id
        FROM store_order_items soi
    )
)
AND a.user_id IS NOT NULL
ORDER BY a.user_id;

-- Query 10: Monthly counts of identified customers with orders above the overall average order value.
WITH all_orders AS (
    SELECT
        o.order_id,
        o.user_id,
        o.order_date,
        oi.product_id,
        oi.quantity,
        'online' AS shop_type
    FROM orders_sql_project o
    JOIN order_items_sql_project oi
        ON o.order_id = oi.order_id

    UNION ALL

    SELECT
        so.store_order_id AS order_id,
        so.user_id,
        so.order_date,
        soi.product_id,
        soi.quantity,
        'offline' AS shop_type
    FROM store_orders so
    JOIN store_order_items soi
        ON so.store_order_id = soi.store_order_id
),

order_checks AS (
    SELECT
        shop_type,
        order_id,
        user_id,
        EXTRACT(MONTH FROM order_date) AS order_month,
        SUM(quantity * product_price) AS order_check
    FROM all_orders a
    LEFT JOIN products_sql_project p
        ON a.product_id = p.product_id
    GROUP BY shop_type, order_id, user_id, order_month
),

avg_check AS (
    SELECT
        AVG(order_check) AS avg_check
    FROM order_checks
),

order_above_average AS (
    SELECT *
    FROM order_checks
    WHERE order_check > (SELECT avg_check FROM avg_check)
)

SELECT
    order_month,
    COUNT(DISTINCT user_id) AS users_count
FROM order_above_average
WHERE user_id IS NOT NULL
GROUP BY order_month
ORDER BY order_month;