# Scripts Python

Os scripts são independentes por desenho, acompanhando os arquivos solicitados
em cada questão do desafio.

| Script | Questão | Entrada | Saída |
|---|---|---|---|
| `generate_schema.py` | Q2 | todos os CSVs | `sql/schema/schema.sql` |
| `load_data.py` | Q3 | CSVs, schema e `.env` | tabelas brutas no PostgreSQL |
| `forecast_baseline.py` | Q6 | PostgreSQL | previsões mensais, total e MAE no terminal |
| `recommendation_system.py` | Q7 | quatro CSVs | Top 5 similares no terminal |

Execute os comandos a partir da raiz do repositório.

## Geração de schema

```shell
python scripts/generate_schema.py --input data/raw --output sql/schema/schema.sql
```

O script lê integralmente cada CSV e usa somente `argparse`, `csv`, `datetime`,
`os`, `re` e `typing`, todos da biblioteca padrão.

## Carga

```shell
python scripts/load_data.py --input data/raw --schema sql/schema/schema.sql
```

Requer PostgreSQL disponível e `.env` configurado. Cada arquivo é carregado via
`COPY`; falhas são reportadas por tabela e causam rollback daquela carga.

## Forecast

```shell
python scripts/forecast_baseline.py --product "Bússola de Bordo 702"
```

Requer banco carregado. A previsão usa somente outubro a dezembro de 2025 e não
atualiza a janela com observações do teste.

## Recomendação

```shell
python scripts/recommendation_system.py
```

O caminho dos CSVs é resolvido em relação ao próprio script, portanto o comando
não depende do diretório atual.

## Dependências

`generate_schema.py` não precisa de instalação externa. Os demais scripts usam
as dependências fixadas em [`../requirements.txt`](../requirements.txt).
