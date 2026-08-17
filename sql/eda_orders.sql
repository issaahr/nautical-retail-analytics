-- ============================================================================
-- EDA - Análise exploratória da tabela orders
-- ============================================================================
-- Esta análise é realizada sobre a tabela orders no banco PostgreSQL após a
-- ingestão dos dados brutos. Não são aplicadas transformações ou filtros de
-- negócio antes das consultas.
--
-- Objetivo:
-- - verificar volume e período dos dados;
-- - analisar a distribuição dos valores;
-- - identificar nulos, duplicidades e inconsistências;
-- - avaliar a distribuição dos status dos pedidos;
-- - identificar possíveis outliers.
--
-- As conclusões desta análise servem de apoio às decisões metodológicas das
-- questões posteriores, mas não substituem as regras definidas em cada questão.


-- ============================================================================
-- EDA 1 - Visão geral
-- ============================================================================
-- Verifica o volume de registros e o período coberto pela tabela.
-- O período é obtido a partir de created_at apenas para caracterizar o dataset;
-- análises de vendas que dependam da data da transação utilizam placed_at.

SELECT
    COUNT(*) AS total_rows,
    MIN(created_at) AS min_created_at,
    MAX(created_at) AS max_created_at
FROM orders;


-- ============================================================================
-- EDA 2 - Estatísticas da coluna total
-- ============================================================================
-- Os valores são arredondados para duas casas apenas para facilitar a leitura;
-- os cálculos estatísticos utilizam os valores originais da coluna.

SELECT
    COUNT(total) AS count,
    MIN(total) AS min_total,
    MAX(total) AS max_total,
    ROUND(AVG(total), 2) AS avg_total,
    ROUND(
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY total)::numeric,
        2
    ) AS q1,
    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY total)::numeric,
        2
    ) AS median,
    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY total)::numeric,
        2
    ) AS q3
FROM orders;


-- ============================================================================
-- EDA 3 - Nulos e valores inválidos
-- ============================================================================
-- Verifica campos nulos e valores não positivos em total.
-- A ausência de salesperson_id é analisada separadamente por canal na EDA 6,
-- pois seu significado pode depender do processo de venda.

SELECT
    COUNT(*) FILTER (WHERE id IS NULL) AS null_id,
    COUNT(*) FILTER (WHERE order_number IS NULL) AS null_order_number,
    COUNT(*) FILTER (WHERE channel IS NULL) AS null_channel,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE salesperson_id IS NULL) AS null_salesperson_id,
    COUNT(*) FILTER (WHERE location_id IS NULL) AS null_location_id,
    COUNT(*) FILTER (WHERE status IS NULL) AS null_status,
    COUNT(*) FILTER (WHERE subtotal IS NULL) AS null_subtotal,
    COUNT(*) FILTER (WHERE discount_amount IS NULL) AS null_discount,
    COUNT(*) FILTER (WHERE total IS NULL) AS null_total,
    COUNT(*) FILTER (WHERE placed_at IS NULL) AS null_placed_at,
    COUNT(*) FILTER (WHERE created_at IS NULL) AS null_created_at,
    COUNT(*) FILTER (WHERE updated_at IS NULL) AS null_updated_at
FROM orders;

SELECT
    COUNT(*) AS non_positive_total
FROM orders
WHERE total <= 0;


-- ============================================================================
-- EDA 4 - Distribuição dos status
-- ============================================================================
-- A tabela possui diferentes estados de pedido. A distribuição é analisada
-- separadamente para entender seu impacto no volume de registros e no valor
-- financeiro.
--
-- Esta consulta é exploratória: ela não define quais status representam
-- "venda" ou "demanda válida". Essa decisão é feita conforme o objetivo de
-- cada análise posterior.

SELECT
    status,
    COUNT(*) AS n_orders,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS pct_orders,
    ROUND(SUM(total), 2) AS total_value
FROM orders
GROUP BY status
ORDER BY n_orders DESC;


-- ============================================================================
-- EDA 5 - Consistência dos valores
-- ============================================================================
-- Verifica se total corresponde ao subtotal após a aplicação do desconto.
-- A tolerância de 0.01 considera possíveis diferenças de arredondamento
-- monetário.

SELECT
    COUNT(*) AS inconsistent_rows
FROM orders
WHERE ABS(subtotal - discount_amount - total) > 0.01;


-- ============================================================================
-- EDA 6 - Nulos de salesperson_id por canal
-- ============================================================================
-- A ausência de salesperson_id pode ser esperada em determinados canais.
-- Por isso, além da quantidade absoluta, calcula-se a proporção de nulos
-- dentro de cada canal para evitar interpretar o total global isoladamente.

SELECT
    channel,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE salesperson_id IS NULL
    ) AS null_salesperson,
    ROUND(
        COUNT(*) FILTER (
            WHERE salesperson_id IS NULL
        ) * 100.0 / COUNT(*),
        2
    ) AS null_pct
FROM orders
GROUP BY channel
ORDER BY channel;


-- ============================================================================
-- EDA 7 - Duplicidade das chaves
-- ============================================================================
-- Verifica duplicidades nas colunas utilizadas como identificadores dos
-- pedidos. A ausência de duplicidade reforça a integridade estrutural da
-- tabela para as análises posteriores.

SELECT
    COUNT(*) - COUNT(DISTINCT id) AS duplicated_ids,
    COUNT(*) - COUNT(DISTINCT order_number) AS duplicated_order_numbers
FROM orders;


-- ============================================================================
-- EDA 8 - Outliers em total
-- ============================================================================
-- Utiliza o método do IQR para identificar valores estatisticamente extremos.
-- Um outlier estatístico não é automaticamente considerado um erro de dados:
-- pedidos de alto valor podem ser legítimos no contexto do varejo náutico.

WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY total) AS q1,
        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY total) AS q3
    FROM orders
),
limits AS (
    SELECT
        q1,
        q3,
        q3 - q1 AS iqr,
        q3 + 1.5 * (q3 - q1) AS upper_fence
    FROM quartiles
)
SELECT
    ROUND(q1::numeric, 2) AS q1,
    ROUND(q3::numeric, 2) AS q3,
    ROUND(iqr::numeric, 2) AS iqr,
    ROUND(upper_fence::numeric, 2) AS upper_fence,
    COUNT(o.*) AS n_outliers
FROM orders o
CROSS JOIN limits
WHERE o.total > limits.upper_fence
GROUP BY q1, q3, iqr, upper_fence;


-- ============================================================================
-- EDA 9 - Conclusão sobre a qualidade dos dados
-- ============================================================================
-- Síntese dos principais achados observados nas consultas anteriores.
--
-- A tabela orders apresenta qualidade estrutural suficiente para as análises
-- propostas. Não foram identificadas duplicidades nas chaves analisadas,
-- valores não positivos em total ou inconsistências entre subtotal,
-- discount_amount e total.
--
-- A ausência de salesperson_id concentra-se no canal e-commerce, enquanto
-- os pedidos POS apresentam o campo preenchido. Esse comportamento é
-- compatível com a diferença entre os canais e não é tratado como erro.
--
-- Os diferentes status de pedido representam estados distintos do processo
-- e devem ser considerados conforme o objetivo de cada análise. A EDA apenas
-- descreve sua distribuição; não define isoladamente quais estados devem
-- ser considerados como receita ou demanda.
--
-- Os valores identificados pelo metodo do IQR são potenciais outliers
-- estatísticos, mas não são automaticamente classificados como erros, pois
-- pedidos de maior valor podem ser compatíveis com o domínio do negócio.