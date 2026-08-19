# Respostas e entregáveis

Valores calculados sobre o snapshot atual de `data/raw/`. Este documento
concentra o que precisa ser informado ou anexado na interface do desafio.

## Q1 — EDA de `orders`

### Visão geral

- Linhas: **48.998**.
- Colunas: **13**.
- Menor `created_at`: **2020-01-01 01:19:28**.
- Maior `created_at`: **2026-12-31 23:43:09**.
- Menor `total`: **R$ 32,62**.
- Maior `total`: **R$ 127.262,02**.
- Média de `total`: **R$ 28.704,99**.

### Q1.2 — Validação

**R$ 28.704,99.**

### Q1.3 — Interpretação

A tabela possui boa integridade estrutural para análises iniciais: não há nulos
em `total`, valores não positivos, IDs ou números de pedido duplicados, nem
divergências entre `subtotal - discount_amount` e `total`. O método do IQR
identificou 452 valores altos, mas eles não devem ser removidos automaticamente,
pois pedidos elevados são plausíveis no varejo náutico. Os 24.131 nulos em
`salesperson_id` concentram-se no e-commerce e parecem coerentes com o canal.
Antes de analisar receita, é necessário definir os status válidos e relacionar
`orders` às tabelas de itens, produtos, pagamentos e devoluções.

Entregáveis: [`../notebooks/exploratory_analysis.ipynb`](../notebooks/exploratory_analysis.ipynb)
e [`../sql/eda_orders.sql`](../sql/eda_orders.sql).

## Q2 — Schema PostgreSQL

### Q2.1

Enviar [`../scripts/generate_schema.py`](../scripts/generate_schema.py). O script
usa apenas módulos da biblioteca padrão do Python 3.

### Q2.2

Enviar [`../sql/schema/schema.sql`](../sql/schema/schema.sql), contendo um
`CREATE TABLE` para cada um dos 24 CSVs.

## Q3 — Carregamento

### Q3.1

Enviar [`../scripts/load_data.py`](../scripts/load_data.py). A carga usa `COPY`,
mantém nulos e caracteres da origem e percorre todos os CSVs.

### Q3.2 — Validação

| Tabela | Linhas |
|---|---:|
| `customers` | 2.000 |
| `orders` | 48.998 |
| `order_items` | 147.320 |
| `payments` | 53.546 |
| **Total** | **251.864** |

## Q4 — Clientes fiéis

### Q4.1

Enviar [`../sql/loyal_customers.sql`](../sql/loyal_customers.sql).

O resultado validado para os Top 10 é:

| Posição | Cliente | Ticket médio | Categorias distintas |
|---:|---:|---:|---:|
| 1 | 22 | R$ 41.839,94 | 14 |
| 2 | 1477 | R$ 41.648,30 | 14 |
| 3 | 929 | R$ 41.645,23 | 14 |
| 4 | 1116 | R$ 40.983,58 | 14 |
| 5 | 1691 | R$ 40.773,57 | 14 |
| 6 | 774 | R$ 40.340,44 | 14 |
| 7 | 1470 | R$ 40.021,27 | 14 |
| 8 | 1599 | R$ 39.904,66 | 14 |
| 9 | 965 | R$ 39.841,05 | 14 |
| 10 | 1722 | R$ 39.532,94 | 14 |

A categoria com maior quantidade para esse grupo é **Hélices**, com **492
itens**.

### Q4.2 — Explicação

Faturamento e frequência são calculados diretamente em `orders`, evitando que o
join com itens multiplique o valor de um pedido. A diversidade percorre
`orders → order_items → product_variants → products` e conta
`COUNT(DISTINCT products.category_id)`. Depois do filtro de pelo menos 13
categorias, o ranking usa ticket médio decrescente e `customer_id` crescente no
desempate. O CTE `loyal_customers` limita o conjunto antes da soma de
`order_items.quantity`, garantindo que a categoria final reflita apenas os Top
10.

## Q5 — Calendário e média por dia da semana

### Q5.1

Enviar [`../sql/sales_calendar.sql`](../sql/sales_calendar.sql).

| Dia | Média diária incluindo zeros |
|---|---:|
| Domingo | R$ 157.616,13 |
| Segunda-feira | R$ 158.241,15 |
| Terça-feira | R$ 166.118,83 |
| Quarta-feira | R$ 173.605,44 |
| **Quinta-feira** | **R$ 157.154,32** |
| Sexta-feira | R$ 170.193,68 |
| Sábado | R$ 164.858,27 |

Portanto, **Quinta-feira** possui a pior média no canal `pos`.

### Q5.2 — Explicação

Agrupar diretamente `orders` considera apenas datas que possuem registros. O
calendário cria uma linha para todos os dias do período; o `LEFT JOIN` preserva
essas datas e o `COALESCE` transforma ausência de venda em zero. Se um dia da
semana tiver muitas datas sem vendas, sua média correta diminui. Ignorar essas
datas inflaria o resultado e poderia levar à decisão operacional errada.

## Q6 — Previsão de demanda

### Q6.1

Enviar [`../scripts/forecast_baseline.py`](../scripts/forecast_baseline.py).

| Mês | Real | Previsto | Erro absoluto |
|---|---:|---:|---:|
| Janeiro/2026 | 76 | 32,67 | 43,33 |
| Fevereiro/2026 | 55 | 32,67 | 22,33 |
| Março/2026 | 51 | 32,67 | 18,33 |

MAE: **28,00 unidades**.

### Q6.2 — Validação

**98 unidades** para o trimestre, após arredondar a soma das previsões.

### Q6.3 — Explicação

O baseline usa a média das quantidades de outubro, novembro e dezembro de 2025:
25, 54 e 19 unidades, resultando em 32,67 unidades por mês. O valor é calculado
somente com dados até 31/12/2025 e aplicado aos três meses de teste; os valores
reais de 2026 entram apenas no cálculo do erro, evitando *data leakage*.

O baseline é útil como referência simples, mas não é adequado como modelo final
para este produto: o MAE de 28 unidades é elevado e a previsão subestima todo o
trimestre. Uma limitação é produzir uma previsão constante, sem capturar
tendência, sazonalidade, promoção ou ruptura de estoque.

## Q7 — Recomendação

### Q7.1

Enviar [`../scripts/recommendation_system.py`](../scripts/recommendation_system.py).

Top 5 validado:

| Posição | Produto | Similaridade |
|---:|---|---:|
| 1 | Vela Mestra 1913 | 0,2452 |
| 2 | Cabo Náutico 2105 | 0,2300 |
| 3 | GPS Plotter 2249 | 0,2148 |
| 4 | Motor de Popa 1540 | 0,2121 |
| 5 | Vela Mestra 3870 | 0,2088 |

### Q7.2 — Validação

**Vela Mestra 1913.**

### Q7.3 — Explicação

A matriz possui clientes nas linhas e produtos nas colunas. Cada célula vale 1
quando o cliente comprou o produto ao menos uma vez e 0 caso contrário; a
quantidade é ignorada. A similaridade de cosseno compara os vetores de clientes
de cada par de produtos: valores maiores indicam maior sobreposição proporcional
de compradores. Uma limitação é ignorar quantidade, frequência e recência, além
de sofrer com *cold start* para produtos ou clientes novos.

## Perguntas finais

As respostas abaixo são pessoais e devem ser preenchidas pelo candidato, não
inferidas do código:

- Questão com maior facilidade: **a preencher**.
- Questão de que mais gostou: **a preencher**.

## Material complementar

O dashboard obrigatório existe localmente, mas não é versionado nesta etapa. No
momento da submissão final, revisar o painel, remover a regra temporária de
ignore do `.pbix` e anexar o arquivo no campo 20.

