"""
load_data.py

Carrega todos os arquivos CSV de um diretorio de origem no PostgreSQL,
respeitando o schema gerado por generate_schema.py (Q2). Nao realiza
nenhum tratamento dos dados -- sem remocao de nulos, sem correcao de
caracteres especiais -- o conteudo dos CSVs e carregado exatamente como
esta, usando o comando COPY do PostgreSQL.

O nome de cada tabela e derivado do nome do arquivo CSV, usando a mesma
normalizacao aplicada em generate_schema.py, para garantir que os nomes
batam com os das tabelas criadas pelo schema.sql.

Uso (executado a partir da pasta scripts/):
    python load_data.py --input ../data/raw --schema ../sql/schema/schema.sql
"""

import os
import re
import argparse
import psycopg2
from dotenv import load_dotenv


# ---------------------------------------------------------------------------
# Nomeacao de tabelas (espelha generate_schema.py)
# ---------------------------------------------------------------------------

def sanitize_identifier(name: str) -> str:
    """Mesma normalizacao usada em generate_schema.py. Precisa ser identica
    para que o nome de tabela aqui bata com o nome definido no schema.sql."""
    name = name.strip().lower()
    name = re.sub(r"[^a-z0-9_]", "_", name)
    if re.match(r"^\d", name):
        name = f"col_{name}"
    return name


# ---------------------------------------------------------------------------
# Conexao
# ---------------------------------------------------------------------------

REQUIRED_ENV_VARS = ["POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD",
                     "POSTGRES_HOST", "POSTGRES_PORT"]


def get_connection():
    load_dotenv()

    missing = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]
    if missing:
        raise SystemExit(
            f"Variavel(is) de ambiente ausente(s): {', '.join(missing)}. "
            f"Configure o arquivo .env na raiz do projeto (ver .env.example)."
        )

    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST"),
        port=os.getenv("POSTGRES_PORT"),
        dbname=os.getenv("POSTGRES_DB"),
        user=os.getenv("POSTGRES_USER"),
        password=os.getenv("POSTGRES_PASSWORD"),
    )


# ---------------------------------------------------------------------------
# Schema e carga
# ---------------------------------------------------------------------------

def apply_schema(conn, schema_path: str):
    """Executa o schema.sql da Q2. CREATE TABLE IF NOT EXISTS torna isso
    seguro de rodar repetidamente sem apagar tabelas existentes."""
    with open(schema_path, "r", encoding="utf-8") as f:
        schema_sql = f.read()
    with conn.cursor() as cur:
        cur.execute(schema_sql)
    conn.commit()
    print(f"Schema aplicado a partir de: {schema_path}")


def load_csv(conn, csv_path: str, table_name: str) -> int:
    """
    Carrega um CSV inteiro na tabela via COPY, sem transformar nenhum
    valor. TRUNCATE antes da carga torna o script seguro para reexecucao
    (evita duplicar linhas em uma segunda rodada) sem alterar o conteudo
    dos dados de origem -- e uma operacao sobre o destino, nao sobre o CSV.
    """
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE TABLE {table_name};")
        with open(csv_path, "r", encoding="utf-8") as f:
            cur.copy_expert(
                f"COPY {table_name} FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')",
                f,
            )
        cur.execute(f"SELECT COUNT(*) FROM {table_name};")
        row_count = cur.fetchone()[0]
    conn.commit()
    return row_count


def load_all(input_dir: str, schema_path: str) -> dict[str, int]:
    csv_files = sorted(f for f in os.listdir(input_dir) if f.lower().endswith(".csv"))
    if not csv_files:
        raise SystemExit(f"Nenhum arquivo .csv encontrado em: {input_dir}")

    conn = get_connection()
    loaded_counts: dict[str, int] = {}
    try:
        apply_schema(conn, schema_path)

        for csv_file in csv_files:
            table_name = sanitize_identifier(os.path.splitext(csv_file)[0])
            csv_path = os.path.join(input_dir, csv_file)
            try:
                count = load_csv(conn, csv_path, table_name)
                loaded_counts[table_name] = count
                print(f"[ok] {csv_file} -> {table_name} ({count} linhas)")
            except Exception as e:
                conn.rollback()
                print(f"[erro] Falha ao carregar {csv_file} em '{table_name}': {e}")
    finally:
        conn.close()

    return loaded_counts


def print_validation_summary(loaded_counts: dict[str, int]):
    """Soma de linhas de customers + orders + order_items + payments (Q3.2)."""
    tabelas_alvo = ["customers", "orders", "order_items", "payments"]
    print("\n--- Validacao Q3.2 ---")
    total = 0
    for tabela in tabelas_alvo:
        count = loaded_counts.get(tabela)
        if count is None:
            print(f"  [aviso] tabela '{tabela}' nao foi carregada nesta execucao")
            continue
        print(f"  {tabela}: {count} linhas")
        total += count
    print(f"  TOTAL: {total} linhas")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description="Carrega todos os CSVs no PostgreSQL, respeitando o schema da Q2."
    )
    parser.add_argument(
        "--input", default="../data/raw",
        help="Diretorio contendo os arquivos CSV de origem (default: ../data/raw)"
    )
    parser.add_argument(
        "--schema", default="../sql/schema/schema.sql",
        help="Caminho do schema.sql a aplicar antes da carga (default: ../sql/schema/schema.sql)"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    counts = load_all(args.input, args.schema)
    print_validation_summary(counts)