-- ============================================================================
-- Q4.1 - Clientes fiéis: Ticket Médio e Diversidade de Categorias
-- ============================================================================
-- Receita e frequência são calculadas no nível de orders para evitar que o
-- JOIN com order_items multiplique o valor total de um pedido.

WITH customer_revenue AS (
    -- Métricas no nível do pedido.
    SELECT
        customer_id,
        SUM(total) AS total_revenue,
        COUNT(DISTINCT id) AS frequency
    FROM orders
    GROUP BY customer_id
),
customer_category_diversity AS (
    -- A categoria é obtida pela cadeia:
    -- orders -> order_items -> product_variants -> products -> categories.
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category_id) AS category_diversity
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    JOIN product_variants pv ON pv.id = oi.product_variant_id
    JOIN products p ON p.id = pv.product_id
    GROUP BY o.customer_id
),
customer_metrics AS (
    SELECT
        cr.customer_id,
        cr.total_revenue,
        cr.frequency,
        cr.total_revenue / cr.frequency AS avg_ticket,
        ccd.category_diversity
    FROM customer_revenue cr
    JOIN customer_category_diversity ccd
        ON ccd.customer_id = cr.customer_id
)
SELECT
    customer_id,
    total_revenue,
    frequency,
    ROUND(avg_ticket, 2) AS ticket_medio,
    category_diversity
FROM customer_metrics
WHERE category_diversity >= 13
ORDER BY avg_ticket DESC, customer_id
LIMIT 10;


-- ============================================================================
-- Q4.2 - Categoria mais consumida pelos Top 10 clientes fiéis
-- ============================================================================
-- Primeiro identifica os mesmos Top 10 da Q4.1. Depois, a cadeia de joins é
-- usada para chegar aos itens e categorias comprados exclusivamente por eles.

WITH customer_revenue AS (
    SELECT
        customer_id,
        SUM(total) AS total_revenue,
        COUNT(DISTINCT id) AS frequency
    FROM orders
    GROUP BY customer_id
),
customer_category_diversity AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category_id) AS category_diversity
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    JOIN product_variants pv ON pv.id = oi.product_variant_id
    JOIN products p ON p.id = pv.product_id
    GROUP BY o.customer_id
),
customer_metrics AS (
    SELECT
        cr.customer_id,
        cr.total_revenue / cr.frequency AS avg_ticket,
        ccd.category_diversity
    FROM customer_revenue cr
    JOIN customer_category_diversity ccd
        ON ccd.customer_id = cr.customer_id
),
loyal_customers AS (
    -- Aplica diversidade mínima, ranking, desempate e limite antes de
    -- calcular as quantidades por categoria.
    SELECT customer_id
    FROM customer_metrics
    WHERE category_diversity >= 13
    ORDER BY avg_ticket DESC, customer_id
    LIMIT 10
)
SELECT
    p.category_id,
    c.name AS category_name,
    SUM(oi.quantity) AS total_quantity
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN product_variants pv ON pv.id = oi.product_variant_id
JOIN products p ON p.id = pv.product_id
JOIN categories c ON c.id = p.category_id
-- Restringe a análise aos clientes definidos no Top 10.
WHERE o.customer_id IN (
    SELECT customer_id
    FROM loyal_customers
)
GROUP BY p.category_id, c.name
ORDER BY total_quantity DESC
LIMIT 1;
