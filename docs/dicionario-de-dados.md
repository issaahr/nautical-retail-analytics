# Dicionário dos dados brutos

O snapshot contém 24 arquivos e 433.424 registros. As chaves abaixo são
relações lógicas observadas no schema relacional; o `schema.sql` bruto não cria
constraints, pois foi gerado por inferência dos CSVs.

| Tabela | Linhas | Grão | Chave lógica | Relacionamentos principais |
|---|---:|---|---|---|
| `addresses` | 3.998 | endereço de cliente | `id` | `customer_id → customers.id` |
| `attributes` | 8 | atributo de variante | `id` | referenciado por `variant_attribute_values` |
| `brands` | 12 | marca | `id` | referenciada por `products` |
| `categories` | 14 | categoria de produto | `id` | `parent_category_id → categories.id` |
| `customers` | 2.000 | cliente | `id` | referenciado por pedidos, endereços e devoluções |
| `employees` | 15 | funcionário | `id` | `primary_location_id → locations.id` |
| `fiscal_invoices` | 34.365 | nota fiscal | `id` | `order_id → orders.id` |
| `goods_receipt_items` | 4.733 | item recebido | `id` | recebimento e item da ordem de compra |
| `goods_receipts` | 1.548 | recebimento de mercadoria | `id` | ordem de compra e funcionário recebedor |
| `locations` | 6 | loja ou armazém | `id` | referenciada por vendas, estoque e compras |
| `order_items` | 147.320 | item de pedido | `id` | `order_id → orders.id`; variante de produto |
| `orders` | 48.998 | pedido de venda | `id` | cliente, vendedor e local |
| `payments` | 53.546 | pagamento de pedido | `id` | `order_id → orders.id` |
| `product_suppliers` | 1.520 | vínculo variante–fornecedor | variante + fornecedor | variante e fornecedor |
| `product_variants` | 1.009 | variante comercial | `id` | `product_id → products.id` |
| `products` | 500 | produto de catálogo | `id` | marca e categoria |
| `purchase_order_items` | 6.059 | item de ordem de compra | `id` | ordem de compra e variante |
| `purchase_orders` | 2.000 | ordem de compra | `id` | fornecedor, comprador e destino |
| `return_items` | 1.384 | item devolvido | `id` | devolução, item vendido e variante de troca |
| `returns` | 980 | processo de devolução | `id` | pedido, cliente e local de recebimento |
| `stock_levels` | 6.054 | saldo de variante por local | variante + local | variante e local |
| `stock_movements` | 115.312 | movimento de estoque | `id` | variante, local, funcionário e referência operacional |
| `suppliers` | 25 | fornecedor | `id` | compras e vínculos de fornecimento |
| `variant_attribute_values` | 2.018 | valor de atributo por variante | variante + atributo | variante e atributo |

## Cadeias usadas nas questões

### Venda até produto e categoria

```text
orders.id
  → order_items.order_id
  → order_items.product_variant_id
  → product_variants.id
  → product_variants.product_id
  → products.id
  → products.category_id
  → categories.id
```

Essa cadeia sustenta diversidade de categorias, quantidade por categoria,
demanda por produto, margem e recomendação.

### Devolução até produto

```text
returns.id
  → return_items.return_id
  → return_items.order_item_id
  → order_items.id
  → product_variants.id
  → products.id
```

### Compra e recebimento

```text
purchase_orders.id
  → purchase_order_items.purchase_order_id
  → goods_receipt_items.purchase_order_item_id
  → goods_receipts.id
```

## Colunas críticas por domínio

- Vendas: `orders.id`, `customer_id`, `channel`, `status`, `total`, `placed_at`.
- Itens: `order_items.order_id`, `product_variant_id`, `quantity`, `unit_price`.
- Produto: `product_variants.product_id`, `cost_price`, `products.category_id`.
- Clientes: `customers.id`, `person_type`, `is_active`, `created_at`.
- Estoque: variante, local, tipo de movimento, quantidade e `occurred_at`.
- Devoluções: status, ação (`refund` ou `exchange`), quantidade e valor reembolsado.

Os nomes e tipos de todas as colunas estão materializados em
[`../sql/schema/schema.sql`](../sql/schema/schema.sql).
