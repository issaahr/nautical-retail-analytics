-- ============================================================================
-- Q5 - Dimensão de calendário: média de vendas por dia da semana (lojas físicas)
-- ============================================================================
-- O calendário inclui todos os dias do período para que dias sem vendas também
-- entrem na média como zero. Usamos MAX(placed_at) do dataset como limite final,
-- representando a data mais atual de venda presente no arquivo.

WITH date_bounds AS (
    -- Período analisado apenas para lojas físicas.
    SELECT
        MIN(placed_at)::date AS min_date,
        MAX(placed_at)::date AS max_date
    FROM orders
    WHERE channel = 'pos'
),
calendar AS (
    -- Gera uma linha para cada dia do período, inclusive dias sem vendas.
    SELECT generate_series(min_date, max_date, interval '1 day')::date AS sale_date
    FROM date_bounds
),
calendar_with_weekday AS (
    SELECT
        sale_date,
        EXTRACT(DOW FROM sale_date) AS weekday_number,
        CASE EXTRACT(DOW FROM sale_date)
            WHEN 0 THEN 'Domingo'
            WHEN 1 THEN 'Segunda-feira'
            WHEN 2 THEN 'Terça-feira'
            WHEN 3 THEN 'Quarta-feira'
            WHEN 4 THEN 'Quinta-feira'
            WHEN 5 THEN 'Sexta-feira'
            WHEN 6 THEN 'Sábado'
        END AS weekday_name
    FROM calendar
),
daily_sales AS (
    -- Soma as vendas de cada dia antes do cruzamento com o calendário.
    SELECT
        placed_at::date AS sale_date,
        SUM(total) AS daily_total
    FROM orders
    WHERE channel = 'pos'
    GROUP BY placed_at::date
)
SELECT
    cw.weekday_name,
    ROUND(AVG(COALESCE(ds.daily_total, 0)), 2) AS avg_daily_sales,
    COUNT(*) AS total_days_in_period,
    COUNT(ds.daily_total) AS days_with_sales
FROM calendar_with_weekday cw
-- LEFT JOIN preserva os dias do calendário sem registro em orders.
LEFT JOIN daily_sales ds ON ds.sale_date = cw.sale_date
GROUP BY cw.weekday_name, cw.weekday_number
ORDER BY cw.weekday_number;