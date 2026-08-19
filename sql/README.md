# SQL

Consultas PostgreSQL organizadas por questão e por consumo analítico.

| Arquivo | Finalidade | Grão principal |
|---|---|---|
| `schema/schema.sql` | tabelas brutas inferidas dos CSVs | uma tabela por fonte |
| `eda_orders.sql` | Q1 — perfil e qualidade de `orders` | pedido ou agregado |
| `loyal_customers.sql` | Q4 — clientes elite e categoria líder | cliente/categoria |
| `sales_calendar.sql` | Q5 — média incluindo dias sem venda | dia da semana |
| `vw_dashboard.sql` | views para o painel executivo | definido por view |

## Ordem de execução

1. Gerar `schema/schema.sql` com `scripts/generate_schema.py`.
2. Aplicar o schema e carregar os dados com `scripts/load_data.py`.
3. Executar os SQLs das questões em qualquer ordem.
4. Executar `vw_dashboard.sql` antes de atualizar o painel.

O Compose monta `sql/` em `/sql` como somente leitura. A partir da raiz, os
arquivos podem ser executados no PostgreSQL do projeto com as credenciais do
`.env`:

```shell
docker compose exec -T nautical-postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql --no-psqlrc -v ON_ERROR_STOP=1 -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/eda_orders.sql'
docker compose exec -T nautical-postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql --no-psqlrc -v ON_ERROR_STOP=1 -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/loyal_customers.sql'
docker compose exec -T nautical-postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql --no-psqlrc -v ON_ERROR_STOP=1 -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/sales_calendar.sql'
docker compose exec -T nautical-postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql --no-psqlrc -v ON_ERROR_STOP=1 -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/vw_dashboard.sql'
```

## Regras de grão

- Receita e frequência de clientes são calculadas em `orders` antes do join com
  itens, evitando multiplicação do total do pedido.
- Diversidade e quantidade por categoria percorrem itens, variantes e produtos.
- Vendas diárias são agregadas antes do join com o calendário.
- Views por produto usam `product_id`, evitando colisões de nomes duplicados.
- Margem é uma estimativa operacional, não lucro contábil.

## Convenções atuais

- Identificadores SQL usam `snake_case`.
- Q4 e Q5 não filtram status, seguindo a interpretação literal adotada nessas
  questões.
- Views do dashboard consideram `paid` e `confirmed` como vendas efetivadas.
- Datas de transação usam `placed_at`; Q1 usa `created_at` por exigência.

Essas escolhas e seus impactos estão em
[`../docs/decisoes-e-limitacoes.md`](../docs/decisoes-e-limitacoes.md).
