# Dados brutos

Esta pasta recebe os 24 CSVs fornecidos no desafio da LH Nautical. Os arquivos
são a fonte imutável das análises: não devem ser corrigidos, sobrescritos ou
normalizados nesta camada.

## Contrato da camada

- Um arquivo CSV corresponde a uma tabela PostgreSQL com o mesmo nome.
- O cabeçalho define os nomes das colunas.
- Encoding esperado: UTF-8.
- Delimitador esperado: vírgula.
- A carga preserva nulos, caracteres e valores da origem.
- Os CSVs são ignorados pelo Git; somente este README é versionado.
- Resultados derivados devem ir para o banco, `data/processed/` ou `outputs/`.

## Arquivos

### Cadastros

`customers`, `addresses`, `employees`, `locations`, `brands`, `categories`,
`attributes`, `products`, `product_variants`, `variant_attribute_values` e
`suppliers`.

### Vendas e pós-venda

`orders`, `order_items`, `payments`, `fiscal_invoices`, `returns` e
`return_items`.

### Compras e estoque

`product_suppliers`, `purchase_orders`, `purchase_order_items`,
`goods_receipts`, `goods_receipt_items`, `stock_levels` e `stock_movements`.

O inventário com contagens, grãos e chaves está em
[`../../docs/dicionario-de-dados.md`](../../docs/dicionario-de-dados.md).

## Reposição local

Para reproduzir o projeto em outro clone, copie os 24 CSVs originais para esta
pasta. O gerador de schema e o carregador descobrem automaticamente todos os
arquivos com extensão `.csv`.
