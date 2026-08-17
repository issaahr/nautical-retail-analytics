"""
Modelo baseline de previsao de demanda mensal para um produto especifico,
usando a media dos ultimos 3 meses do periodo de treino.

O baseline e calculado uma unica vez utilizando outubro, novembro e
dezembro de 2025 e aplicado ao primeiro trimestre de 2026, sem utilizar
observacoes do periodo de teste na geracao das previsoes.

Fonte dos dados: orders + order_items + product_variants + products,
consultados diretamente no PostgreSQL carregado pela pipeline da Q3.

Uso (executado a partir da pasta scripts/):
    python forecast_baseline.py --product "Bússola de Bordo 702"
"""

import os
import argparse

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv


# ---------------------------------------------------------------------------
# Conexao
# ---------------------------------------------------------------------------

REQUIRED_ENV_VARS = [
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "POSTGRES_HOST",
    "POSTGRES_PORT",
]


def get_engine():
    load_dotenv()

    missing = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]

    if missing:
        raise SystemExit(
            f"Variavel(is) de ambiente ausente(s): {', '.join(missing)}. "
            f"Configure o arquivo .env na raiz do projeto."
        )

    return create_engine(
        f"postgresql+psycopg2://"
        f"{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}"
        f"@{os.getenv('POSTGRES_HOST')}:{os.getenv('POSTGRES_PORT')}"
        f"/{os.getenv('POSTGRES_DB')}"
    )


# ---------------------------------------------------------------------------
# Dataset unificado
# ---------------------------------------------------------------------------

def load_monthly_demand(engine, product_name: str) -> pd.Series:
    """
    Une orders, order_items, product_variants e products, filtra pelo
    produto informado e agrega a quantidade vendida por mes.

    Sao considerados apenas pedidos com status 'paid' ou 'confirmed',
    representando vendas confirmadas/efetivadas para fins de demanda.
    Pedidos 'cancelled' e 'draft' sao excluidos.

    Meses sem vendas sao preenchidos com zero para preservar a continuidade
    da serie temporal.
    """
    query = text("""
        SELECT
            date_trunc('month', o.placed_at)::date AS month,
            SUM(oi.quantity) AS quantity
        FROM orders o
        JOIN order_items oi
            ON oi.order_id = o.id
        JOIN product_variants pv
            ON pv.id = oi.product_variant_id
        JOIN products p
            ON p.id = pv.product_id
        WHERE p.name = :product_name
          AND o.status IN ('paid', 'confirmed')
        GROUP BY date_trunc('month', o.placed_at)
        ORDER BY month
    """)

    df = pd.read_sql(
        query,
        engine,
        params={"product_name": product_name},
    )

    if df.empty:
        raise SystemExit(
            f"Nenhuma venda encontrada para o produto: {product_name!r}"
        )

    df["month"] = pd.to_datetime(df["month"])

    series = (
        df.set_index("month")["quantity"]
        .astype(float)
    )

    # Garante que meses sem vendas tambem existam na serie.
    full_range = pd.date_range(
        series.index.min(),
        series.index.max(),
        freq="MS",
    )

    return series.reindex(full_range, fill_value=0.0)


# ---------------------------------------------------------------------------
# Baseline: media dos ultimos 3 meses do treino
# ---------------------------------------------------------------------------

def baseline_forecast(
    series: pd.Series,
    train_cutoff: pd.Timestamp,
    target_months,
) -> dict:
    """
    Calcula o baseline utilizando os tres ultimos meses do periodo
    de treino e aplica o mesmo valor a todo o horizonte de teste.

    Nenhum dado do periodo de teste participa da geracao das previsoes.
    """
    baseline_window = series.loc[:train_cutoff].tail(3)

    if len(baseline_window) < 3:
        raise ValueError(
            f"Historico de treino insuficiente ate {train_cutoff.date()} "
            f"(apenas {len(baseline_window)} mes(es) disponivel(is))."
        )

    baseline_value = baseline_window.mean()

    return {
        month: baseline_value
        for month in target_months
    }


def mean_absolute_error(
    series: pd.Series,
    forecasts: dict,
) -> float:
    """Calcula o MAE entre previsoes e valores reais."""
    errors = [
        abs(forecasts[month] - series.loc[month])
        for month in forecasts
    ]

    return sum(errors) / len(errors)


# ---------------------------------------------------------------------------
# Execucao principal
# ---------------------------------------------------------------------------

def main(product_name: str):
    engine = get_engine()

    series = load_monthly_demand(
        engine,
        product_name,
    )

    # Dezembro/2025 e o ultimo mes do periodo de treino.
    train_cutoff = pd.Timestamp("2025-12-01")

    # Primeiro trimestre de 2026: periodo de teste.
    test_months = pd.date_range(
        "2026-01-01",
        "2026-03-01",
        freq="MS",
    )

    # Os valores reais do teste sao necessarios apenas para avaliacao.
    missing = [
        month
        for month in test_months
        if month not in series.index
    ]

    if missing:
        raise SystemExit(
            "Sem dados reais para comparar no periodo de teste: "
            f"{[m.strftime('%Y-%m') for m in missing]}. "
            "Verifique se o banco contem vendas ate 03/2026."
        )

    print(f"Produto: {product_name}")

    print(
        "Periodo historico carregado: "
        f"{series.index.min().strftime('%Y-%m')} "
        f"a {series.index.max().strftime('%Y-%m')} "
        f"({len(series)} meses)"
    )

    # -----------------------------------------------------------------------
    # Previsao
    # -----------------------------------------------------------------------

    forecasts = baseline_forecast(
        series,
        train_cutoff,
        test_months,
    )

    # -----------------------------------------------------------------------
    # Avaliacao
    # -----------------------------------------------------------------------

    mae = mean_absolute_error(
        series,
        forecasts,
    )

    total_forecast = sum(forecasts.values())

    print("\n=== Baseline ===")

    for month in test_months:
        real = series.loc[month]
        predicted = forecasts[month]
        absolute_error = abs(predicted - real)

        print(
            f"  {month.strftime('%Y-%m')}: "
            f"previsto={predicted:.2f}  "
            f"real={real:.2f}  "
            f"erro_abs={absolute_error:.2f}"
        )

    print(f"\n  MAE: {mae:.2f}")
    print(
        "  Soma da previsao do trimestre (arredondada): "
        f"{round(total_forecast)}"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Baseline de previsao de demanda mensal."
    )

    parser.add_argument(
        "--product",
        default="Bússola de Bordo 702",
        help="Nome exato do produto (coluna products.name)",
    )

    args = parser.parse_args()

    main(args.product)