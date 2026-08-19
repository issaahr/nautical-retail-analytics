# Decisões, premissas e limitações

Este documento registra escolhas que alteram a interpretação dos resultados.
O objetivo é impedir que filtros ou regras de negócio fiquem escondidos no
código.

## Decisões metodológicas

### D01 — Camada raw preservada

Os CSVs são lidos como fornecidos. Q1 não limpa `orders`, Q2 infere o schema a
partir do conteúdo observado e Q3 não corrige nulos, caracteres ou categorias.

Impacto: problemas da origem continuam visíveis e podem ser diagnosticados sem
perder rastreabilidade.

### D02 — Inferência conservadora de tipos

O gerador lê todas as linhas. Misturas incompatíveis caem em `TEXT`, inteiros
com zero à esquerda são preservados como texto e `products.ncm_code` possui uma
exceção explícita por ser código fiscal.

Impacto: a prioridade é carregar o snapshot sem perda de informação, não criar
um modelo dimensional definitivo.

### D03 — Reexecução da carga

Cada tabela é truncada antes do `COPY`.

Impacto: a carga não duplica linhas, mas substitui o conteúdo anterior da camada
raw no PostgreSQL. Os CSVs não são alterados.

### D04 — Status válidos por finalidade

Previsão, recomendação e views do dashboard consideram `paid` e `confirmed`
como compras efetivadas. `cancelled` e `draft` são excluídos nesses contextos.

Q1 observa todos os status, conforme a premissa de não tratamento. Q4 e Q5
seguem literalmente os SQLs entregues e não aplicam filtro de status, porque a
definição dessas questões não especifica um subconjunto.

Impacto: resultados de Q4/Q5 não devem ser comparados diretamente a métricas do
dashboard sem considerar essa diferença. Uniformizar a regra exigiria uma
decisão de negócio adicional.

### D05 — Datas

- Q1 usa `created_at`, como solicitado.
- Análises de venda e demanda usam `placed_at`, que representa a transação.
- Q5 usa o intervalo completo de datas do canal `pos` e inclui todos os dias.
- Q6 encerra o treino em dezembro de 2025 e avalia janeiro a março de 2026.

### D06 — Dias sem venda

Q5 cria um calendário contínuo e faz `LEFT JOIN` com vendas diárias. Ausência de
pedido vira zero antes da média por dia da semana.

Impacto: dias sem registro reduzem a média, evitando o viés de calcular somente
sobre dias em que houve venda.

### D07 — Granularidade de produto

Itens apontam para `product_variants`; a variante aponta para `products`. A
recomendação usa `product_id`, ignorando tamanho, cor ou outra variante.

O catálogo contém dois IDs com o nome “Bússola de Bordo 702” (`74` e `240`). O
forecast filtra pelo nome e, portanto, agrega IDs homônimos. No trimestre de
teste, o segundo cadastro ainda não havia sido criado, mas a ambiguidade deve
ser resolvida se o modelo for colocado em produção.

### D08 — Receita, margem e lucro

As views calculam margem estimada a partir de preço de venda e custo cadastrado.
Ela não é lucro contábil: impostos, frete, despesas operacionais e outras
apropriações não estão integralmente representados.

### D09 — Dashboard local

O `.pbix` não é versionado nesta etapa. `dashboard/.gitkeep` mantém a pasta no
repositório e `.gitignore` impede upload acidental do binário.

## Limitações analíticas

### EDA

- O método do IQR encontrou 452 valores altos em `total`, mas eles não são
  removidos: no varejo náutico, pedidos elevados podem ser legítimos.
- `salesperson_id` possui 24.131 nulos, concentrados no e-commerce; isso parece
  coerente com o processo, mas depende de confirmação do responsável pelo ERP.
- A qualidade de `orders` não garante a qualidade das demais tabelas.

### Previsão

- A média móvel de três meses produz um valor constante para todo o trimestre.
- O método não modela tendência, sazonalidade, promoções, ruptura de estoque ou
  tempo de reposição.
- O MAE de 28 unidades é alto em relação à demanda média real do teste, portanto
  o baseline serve como referência, não como modelo final de compras.

### Recomendação

- A matriz binária ignora quantidade, recorrência, data e sequência das compras.
- Produtos populares podem parecer semelhantes a muitos itens.
- Clientes ou produtos novos não possuem histórico suficiente, caracterizando
  o problema de *cold start*.

## Pontos para evolução

- Confirmar com negócio se Q4 e Q5 devem excluir `draft` e `cancelled`.
- Definir uma chave canônica para produtos com nomes duplicados.
- Criar testes de integridade referencial e regressão dos números de validação.
- Materializar uma camada tratada somente quando suas regras estiverem fechadas.
- Remover a regra de ignore do `.pbix` no momento da entrega final.

