import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity


# ============================================================
# 1. Leitura dos dados
# ============================================================

orders = pd.read_csv("../data/raw/orders.csv")
order_items = pd.read_csv("../data/raw/order_items.csv")
product_variants = pd.read_csv("../data/raw/product_variants.csv")
products = pd.read_csv("../data/raw/products.csv")


# ============================================================
# 2. Seleção das compras válidas
# ============================================================
# Pedidos pagos ou confirmados são considerados compras válidas.
# Pedidos cancelados ou em rascunho são desconsiderados.

valid_orders = orders[
    orders["status"].isin(["paid", "confirmed"])
]


# ============================================================
# 3. Construção do histórico de compras
# ============================================================
# Relacionamento:
# orders -> order_items -> product_variants -> products
#
# O produto é utilizado como unidade de recomendação, e não
# a variante.

purchases = (
    valid_orders[["id", "customer_id"]]
    .merge(
        order_items[["order_id", "product_variant_id"]],
        left_on="id",
        right_on="order_id",
        how="inner",
    )
    .merge(
        product_variants[["id", "product_id"]],
        left_on="product_variant_id",
        right_on="id",
        how="inner",
    )
    .merge(
        products[["id", "name"]],
        left_on="product_id",
        right_on="id",
        how="inner",
    )
)


# ============================================================
# 4. Matriz Usuário x Produto
# ============================================================
# Cada célula representa apenas presença ou ausência:
# 1 = cliente comprou o produto pelo menos uma vez
# 0 = cliente não comprou
#
# A quantidade comprada e o número de compras são ignorados.

user_item_matrix = pd.crosstab(
    purchases["customer_id"],
    purchases["product_id"],
)

user_item_matrix = (user_item_matrix > 0).astype(int)


# ============================================================
# 5. Similaridade de cosseno entre produtos
# ============================================================
# A transposição faz com que cada linha represente um produto.
# Assim, cada produto é representado pelo vetor dos clientes
# que compraram aquele produto.

product_similarity = cosine_similarity(
    user_item_matrix.T
)

similarity_matrix = pd.DataFrame(
    product_similarity,
    index=user_item_matrix.columns,
    columns=user_item_matrix.columns,
)


# ============================================================
# 6. Ranking de produtos similares
# ============================================================

TARGET_PRODUCT_ID = 180  # Motor de Popa 1949

similar_products = (
    similarity_matrix[TARGET_PRODUCT_ID]
    .drop(TARGET_PRODUCT_ID)
    .sort_values(ascending=False)
    .head(5)
)


# ============================================================
# 7. Associação dos IDs aos nomes dos produtos
# ============================================================

ranking = (
    similar_products
    .rename("similarity")
    .reset_index()
    .merge(
        products[["id", "name"]],
        left_on="product_id",
        right_on="id",
        how="left",
    )
    [["product_id", "name", "similarity"]]
)

ranking["similarity"] = ranking["similarity"].round(4)


# ============================================================
# 8. Resultado
# ============================================================

print("Top 5 produtos mais similares ao 'Motor de Popa 1949':")
print(ranking.to_string(index=False))