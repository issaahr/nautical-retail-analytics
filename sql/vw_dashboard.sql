-- ============================================================================
-- VW 1 - Vendas para a visão executiva
-- ============================================================================
-- Um registro representa um item de pedido.
--
-- A receita considera apenas pedidos com status paid ou confirmed.
-- O valor de venda de cada item é calculado a partir do preço unitário
-- proporcionalmente ao total líquido do pedido, distribuindo o desconto
-- concedido no pedido entre seus itens.
--
-- A granularidade de produto utiliza product_id, pois existem produtos
-- diferentes com o mesmo nome no catálogo.
DROP VIEW IF EXISTS vw_dashboard_sales;
CREATE OR REPLACE VIEW vw_dashboard_sales AS
SELECT
    o.id AS order_id,
    o.placed_at::date AS sale_date,
    EXTRACT(YEAR FROM o.placed_at)::int AS sale_year,
    o.channel,
    o.customer_id,
    p.id AS product_id,
    p.name AS product_name,
    p.category_id,
    c.name AS category_name,
    oi.quantity,

    -- receita líquida com desconto rateado
    oi.quantity * oi.unit_price
        * (o.total / NULLIF(o.subtotal, 0)) AS sales_value,

    -- margem estimada após rateio do desconto
    (
        oi.quantity * oi.unit_price
        * (o.total / NULLIF(o.subtotal, 0))
    ) - (
        oi.quantity * pv.cost_price
    ) AS estimated_margin_value

FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN product_variants pv ON pv.id = oi.product_variant_id
JOIN products p ON p.id = pv.product_id
JOIN categories c ON c.id = p.category_id
WHERE o.status IN ('paid', 'confirmed');

-- ============================================================================
-- VW 2 - Metricas de clientes
-- ============================================================================
-- As metricas de receita e frequencia sao calculadas no nivel de orders para
-- evitar que o JOIN com order_items multiplique o valor dos pedidos.
-- A diversidade de categorias e calculada separadamente no nivel dos itens.
DROP VIEW IF EXISTS vw_dashboard_customers;
CREATE OR REPLACE VIEW vw_dashboard_customers AS
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(DISTINCT id) AS order_count,
        SUM(total) AS total_revenue
    FROM orders
    WHERE status IN ('paid', 'confirmed')
    GROUP BY customer_id
),
customer_categories AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category_id) AS category_diversity
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.id
    JOIN product_variants pv
        ON pv.id = oi.product_variant_id
    JOIN products p
        ON p.id = pv.product_id
    WHERE o.status IN ('paid', 'confirmed')
    GROUP BY o.customer_id
)
SELECT
    co.customer_id,
    co.order_count,
    ROUND(co.total_revenue, 2) AS total_revenue,
    ROUND(co.total_revenue / NULLIF(co.order_count, 0), 2) AS avg_ticket,
    COALESCE(cc.category_diversity, 0) AS category_diversity,
    COALESCE(cc.category_diversity, 0) >= 13 AS is_elite
FROM customer_orders co
LEFT JOIN customer_categories cc
    ON cc.customer_id = co.customer_id;

-- ============================================================================
-- VW 3 - Consumo por categoria dos clientes elite
-- ============================================================================
-- Cliente elite segue a definicao da Q4: pelo menos 13 categorias distintas.
-- O ranking dos clientes e feito por ticket medio, e apenas os 10 primeiros
-- clientes sao considerados na distribuicao de consumo por categoria.
DROP VIEW IF EXISTS vw_dashboard_elite_category_consumption;
CREATE OR REPLACE VIEW vw_dashboard_elite_category_consumption AS
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(DISTINCT id) AS order_count,
        SUM(total) AS total_revenue
    FROM orders
    WHERE status IN ('paid', 'confirmed')
    GROUP BY customer_id
),
customer_categories AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category_id) AS category_diversity
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.id
    JOIN product_variants pv
        ON pv.id = oi.product_variant_id
    JOIN products p
        ON p.id = pv.product_id
    WHERE o.status IN ('paid', 'confirmed')
    GROUP BY o.customer_id
),
top_elite_customers AS (
    SELECT
        co.customer_id
    FROM customer_orders co
    JOIN customer_categories cc
        ON cc.customer_id = co.customer_id
    WHERE cc.category_diversity >= 13
    ORDER BY
        co.total_revenue / NULLIF(co.order_count, 0) DESC,
        co.customer_id
    LIMIT 10
)
SELECT
    p.category_id,
    c.name AS category_name,
    SUM(oi.quantity) AS total_quantity
FROM top_elite_customers tec
JOIN orders o
    ON o.customer_id = tec.customer_id
JOIN order_items oi
    ON oi.order_id = o.id
JOIN product_variants pv
    ON pv.id = oi.product_variant_id
JOIN products p
    ON p.id = pv.product_id
JOIN categories c
    ON c.id = p.category_id
WHERE o.status IN ('paid', 'confirmed')
GROUP BY
    p.category_id,
    c.name;

-- ============================================================================
-- VW 4 - Faturamento e margem estimada por produto
-- ============================================================================
-- A margem e uma estimativa baseada exclusivamente na diferenca entre o
-- preco de venda e o custo cadastrado. Nao representa lucro contabil.
-- O agrupamento utiliza product_id para evitar colisao entre produtos que
-- possuem o mesmo nome no catalogo.
DROP VIEW IF EXISTS vw_dashboard_product_margin;
CREATE OR REPLACE VIEW vw_dashboard_product_margin AS
SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.category_id,
    c.name AS category_name,
    SUM(oi.quantity) AS quantity_sold,
    ROUND(
        SUM(oi.quantity * oi.unit_price),
        2
    ) AS sales_value,
    ROUND(
        SUM(
            oi.quantity
            * (oi.unit_price - pv.cost_price)
        ),
        2
    ) AS estimated_margin_value,
    ROUND(
        100.0 * SUM(
            oi.quantity * (oi.unit_price - pv.cost_price)
        )
        / NULLIF(SUM(oi.quantity * oi.unit_price), 0),
        2
    ) AS estimated_margin_pct
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.id
JOIN product_variants pv
    ON pv.id = oi.product_variant_id
JOIN products p
    ON p.id = pv.product_id
JOIN categories c
    ON c.id = p.category_id
WHERE o.status IN ('paid', 'confirmed')
GROUP BY
    p.id,
    p.name,
    p.category_id,
    c.name;

-- ============================================================================
-- VW 5 - Valor reembolsado por produto
-- ============================================================================
-- Considera apenas devolucoes concluidas e itens cuja acao foi refund.
-- Itens marcados como exchange nao representam reembolso financeiro.
--
-- Grao: um registro por produto.
DROP VIEW IF EXISTS vw_dashboard_product_refunds;
CREATE OR REPLACE VIEW vw_dashboard_product_refunds AS
SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.category_id,
    c.name AS category_name,
    ROUND(
        SUM(ri.quantity * ri.unit_refund_amount),
        2
    ) AS refunded_value
FROM returns r
JOIN return_items ri
    ON ri.return_id = r.id
JOIN order_items oi
    ON oi.id = ri.order_item_id
JOIN product_variants pv
    ON pv.id = oi.product_variant_id
JOIN products p
    ON p.id = pv.product_id
JOIN categories c
    ON c.id = p.category_id
WHERE r.status = 'completed'
  AND ri.action = 'refund'
GROUP BY
    p.id,
    p.name,
    p.category_id,
    c.name;

-- ============================================================================
-- VW 6 - Media de vendas por dia da semana
-- ============================================================================
-- Inclui dias sem vendas no calculo da media, conforme a premissa da Q5.
-- A analise considera apenas o canal POS.
DROP VIEW IF EXISTS vw_dashboard_weekday_sales;
CREATE OR REPLACE VIEW vw_dashboard_weekday_sales AS
WITH date_bounds AS (
    SELECT
        MIN(placed_at)::date AS min_date,
        MAX(placed_at)::date AS max_date
    FROM orders
    WHERE channel = 'pos'
),
calendar AS (
    SELECT
        generate_series(
            min_date,
            max_date,
            interval '1 day'
        )::date AS sale_date
    FROM date_bounds
),
daily_sales AS (
    SELECT
        placed_at::date AS sale_date,
        SUM(total) AS daily_total
    FROM orders
    WHERE channel = 'pos'
    GROUP BY placed_at::date
)
SELECT
    CASE EXTRACT(DOW FROM c.sale_date)
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terca-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sabado'
    END AS weekday_name,
    EXTRACT(DOW FROM c.sale_date)::int AS weekday_number,
    ROUND(
        AVG(COALESCE(ds.daily_total, 0)),
        2
    ) AS avg_daily_sales
FROM calendar c
LEFT JOIN daily_sales ds
    ON ds.sale_date = c.sale_date
GROUP BY
    weekday_number,
    weekday_name
ORDER BY weekday_number;

-- ============================================================================
-- VW 7 - Previsao de demanda
-- ============================================================================
-- Reproduz o baseline oficial da Q6.
-- A previsao corresponde a media das vendas dos tres ultimos meses do
-- periodo de treino (outubro, novembro e dezembro de 2025) e e mantida
-- constante para todo o trimestre de teste.
--
-- A selecao segue o mesmo criterio da analise original: produtos com o nome
-- 'Bússola de Bordo 702'. O catalogo possui dois product_id distintos com
-- esse nome, ambos com vendas, portanto a demanda apresentada e agregada.
--
-- Grao: um registro por mes do periodo de teste.
DROP VIEW IF EXISTS vw_dashboard_demand_forecast;
CREATE OR REPLACE VIEW vw_dashboard_demand_forecast AS
WITH monthly_demand AS (
    SELECT
        p.name AS product_name,
        DATE_TRUNC('month', o.placed_at)::date AS month,
        SUM(oi.quantity) AS quantity_real
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.id
    JOIN product_variants pv
        ON pv.id = oi.product_variant_id
    JOIN products p
        ON p.id = pv.product_id
    WHERE p.name = 'Bússola de Bordo 702'
      AND o.status IN ('paid', 'confirmed')
    GROUP BY
        p.name,
        DATE_TRUNC('month', o.placed_at)
),
baseline AS (
    SELECT
        AVG(quantity_real) AS quantity_forecast
    FROM monthly_demand
    WHERE month BETWEEN DATE '2025-10-01'
                      AND DATE '2025-12-01'
)
SELECT
    md.product_name,
    md.month,
    md.quantity_real,
    ROUND(b.quantity_forecast, 2) AS quantity_forecast,
    ROUND(
        ABS(b.quantity_forecast - md.quantity_real),
        2
    ) AS absolute_error
FROM monthly_demand md
CROSS JOIN baseline b
WHERE md.month BETWEEN DATE '2026-01-01'
                   AND DATE '2026-03-01';

-- VW 8 - Margem estimada por cliente
-- ============================================================================
-- Um registro representa um cliente com pedidos paid ou confirmed.
--
-- A margem estimada corresponde à diferença entre o preço de venda do item
-- e o custo cadastrado da variante, multiplicada pela quantidade vendida.
-- Não representa lucro contábil, pois não considera impostos, frete ou
-- demais custos operacionais.
--
-- A margem é agregada por customer_id para permitir o ranking de clientes
-- por margem estimada acumulada no dashboard.
DROP VIEW IF EXISTS vw_dashboard_customer_margin;
CREATE OR REPLACE VIEW vw_dashboard_customer_margin AS
SELECT
    o.customer_id,
    ROUND(
        SUM(
            oi.quantity::numeric
            * (oi.unit_price - pv.cost_price)
        ),
        2
    ) AS estimated_margin_value
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.id
JOIN product_variants pv
    ON pv.id = oi.product_variant_id
WHERE o.status IN ('paid', 'confirmed')
GROUP BY o.customer_id;
