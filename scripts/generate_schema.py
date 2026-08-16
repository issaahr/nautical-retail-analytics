"""
generate_schema.py

Le todos os arquivos CSV de um diretorio de origem e gera um unico arquivo
schema.sql com as instrucoes CREATE TABLE (PostgreSQL) correspondentes,
uma tabela por CSV.

Restricao do desafio: apenas biblioteca padrao do Python 3
(csv, os, re, datetime). Nao usa pandas/dask/polars.

Uso (executado a partir da pasta scripts/):
    python generate_schema.py --input ../data/raw --output ../sql/schema/schema.sql
"""

import csv
import os
import re
import argparse
from datetime import datetime
from typing import Optional


# ---------------------------------------------------------------------------
# Inferencia de tipos
# ---------------------------------------------------------------------------

INT_RE = re.compile(r"^[+-]?\d+$")
NUMERIC_RE = re.compile(r"^[+-]?\d+(\.\d+)?$")

# Range do tipo INTEGER (4 bytes) no PostgreSQL. Valores fora disso nao
# podem ser classificados como INTEGER, sob risco de "integer out of range"
# na hora da carga (Q3). NUMERIC no Postgres tem precisao arbitraria, entao
# e o fallback seguro para numeros grandes.
PG_INTEGER_MIN = -2147483648
PG_INTEGER_MAX = 2147483647

DATE_FORMATS = ["%Y-%m-%d"]
TIMESTAMP_FORMATS = ["%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"]


def has_meaningful_leading_zero(value: str) -> bool:
    """
    Identifica inteiros com zero a esquerda, como '06100715800' ou '001',
    que provavelmente sao identificadores/codigos e perderiam informacao
    se convertidos para numero. Nao se aplica a decimais: em '01.50' ou
    '0.50', o zero antes do ponto e apenas notacao numerica padrao, entao
    a inferencia numerica e mantida.

    Ha uma ambiguidade inerente aqui (ex: '000123' pode ser um codigo ou
    uma quantidade). A politica adotada prioriza preservacao do dado
    original: inteiros com zero a esquerda viram TEXT.
    """
    v = value.strip()
    if v and v[0] in "+-":
        v = v[1:]
    return len(v) > 1 and v.startswith("0") and "." not in v


def is_boolean(value: str) -> bool:
    # "0"/"1" nao contam como boolean aqui: sao ambiguos com INTEGER,
    # entao a inferencia mais conservadora vence.
    return value.strip().lower() in {"true", "false", "t", "f"}


def is_integer(value: str) -> bool:
    value = value.strip()
    if has_meaningful_leading_zero(value):
        return False
    if not INT_RE.match(value):
        return False
    return PG_INTEGER_MIN <= int(value) <= PG_INTEGER_MAX


def is_numeric(value: str) -> bool:
    value = value.strip()
    if has_meaningful_leading_zero(value):
        return False
    return bool(NUMERIC_RE.match(value))


def _matches_any_format(value: str, formats: list) -> bool:
    for fmt in formats:
        try:
            datetime.strptime(value.strip(), fmt)
            return True
        except ValueError:
            continue
    return False


def is_date(value: str) -> bool:
    return _matches_any_format(value, DATE_FORMATS)


def is_timestamp(value: str) -> bool:
    return _matches_any_format(value, TIMESTAMP_FORMATS)


def infer_value_type(value: str) -> str:
    """Retorna o tipo mais especifico que um unico valor satisfaz."""
    if is_boolean(value):
        return "BOOLEAN"
    if is_integer(value):
        return "INTEGER"
    if is_numeric(value):
        return "NUMERIC"
    if is_date(value):
        return "DATE"
    if is_timestamp(value):
        return "TIMESTAMP"
    return "TEXT"


# Regras explicitas de compatibilidade entre pares de tipos.
# Qualquer par nao listado aqui (e diferente entre si) e considerado
# incompativel e cai em TEXT. Isso evita fallbacks "por ranking" que
# podem gerar combinacoes sem sentido semantico, como INTEGER + DATE
# virando DATE.
COMPATIBLE_PAIRS = {
    frozenset({"INTEGER", "NUMERIC"}): "NUMERIC",
    frozenset({"DATE", "TIMESTAMP"}): "TIMESTAMP",
}

# Excecoes de tipo justificadas por conhecimento de dominio, aplicadas
# depois da inferencia automatica. Diferente de uma heuristica generica
# por nome de coluna, cada excecao aqui e explicita, nomeada e documentada
# com o motivo -- e o motivo e propagado como comentario no schema.sql
# gerado, para ficar visivel a quem revisar o entregavel sem depender de
# nenhum documento externo.
#
# Chave: (nome_do_arquivo_csv, nome_da_coluna_original)
# Valor: (tipo_forcado, justificativa)
COLUMN_TYPE_OVERRIDES = {
    ("products.csv", "ncm_code"): (
        "TEXT",
        "Codigo fiscal (NCM), nao uma quantidade. Os capitulos 01-09 da "
        "tabela NCM (animais vivos e produtos de origem animal) tem codigos "
        "que comecam com zero. Nenhum valor no dataset atual comeca com "
        "zero (catalogo nao inclui esses capitulos), mas o campo e "
        "semanticamente um identificador e deve ser TEXT independente do "
        "conteudo observado, para nao quebrar se o catalogo for expandido."
    ),
}


def merge_types(current: Optional[str], new: str) -> str:
    """
    Combina o tipo acumulado da coluna com o tipo do valor atual.
    Usa uma tabela explicita de compatibilidades; qualquer combinacao
    fora dela (inclusive qualquer mistura envolvendo BOOLEAN) vira TEXT.
    """
    if current is None:
        return new
    if current == new:
        return current

    pair = frozenset({current, new})
    return COMPATIBLE_PAIRS.get(pair, "TEXT")


def infer_column_types(csv_path: str):
    """
    Le o CSV completo e retorna:
      - lista de nomes de coluna (ordem original)
      - dict {coluna: tipo_sql}
    """
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
        except StopIteration:
            return [], {}

        col_types: dict[str, Optional[str]] = {col: None for col in header}
        malformed_rows = 0
        malformed_row_numbers = []

        for row_num, row in enumerate(reader, start=2):  # linha 1 = header
            if len(row) != len(header):
                malformed_rows += 1
                if len(malformed_row_numbers) < 5:
                    malformed_row_numbers.append(row_num)
                continue

            for col, value in zip(header, row):
                value = value.strip()
                if value == "" or value.upper() == "NULL":
                    continue
                value_type = infer_value_type(value)
                col_types[col] = merge_types(col_types[col], value_type)

    # colunas 100% vazias caem em TEXT por padrao
    for col in header:
        if col_types[col] is None:
            col_types[col] = "TEXT"

    if malformed_rows:
        exemplos = ", ".join(str(n) for n in malformed_row_numbers)
        print(f"  [aviso] {malformed_rows} linha(s) com numero de colunas "
              f"diferente do header em {os.path.basename(csv_path)} "
              f"(primeiras ocorrencias: linha(s) {exemplos})")

    return header, col_types


def apply_type_overrides(csv_file: str, header, col_types):
    """
    Aplica COLUMN_TYPE_OVERRIDES sobre o resultado da inferencia automatica.
    Retorna col_types atualizado e uma lista de (coluna, justificativa) para
    as excecoes efetivamente aplicadas neste arquivo, usada para emitir
    comentarios no schema.sql gerado.
    """
    applied = []
    for col in header:
        override = COLUMN_TYPE_OVERRIDES.get((csv_file, col))
        if override is None:
            continue
        forced_type, reason = override
        col_types[col] = forced_type
        applied.append((col, reason))
    return col_types, applied


# ---------------------------------------------------------------------------
# Geracao de SQL
# ---------------------------------------------------------------------------

def sanitize_identifier(name: str) -> str:
    """Normaliza nomes de tabela/coluna para identificadores SQL seguros."""
    name = name.strip().lower()
    name = re.sub(r"[^a-z0-9_]", "_", name)
    if re.match(r"^\d", name):
        name = f"col_{name}"
    return name


def build_create_table(table_name: str, header, col_types) -> str:
    # Nao inferimos NOT NULL: o desafio pede detectar colunas e gerar o
    # schema, nao inferir constraints. Ausencia de nulo no CSV observado
    # nao garante que a coluna seja NOT NULL no modelo de origem.
    lines = [f"CREATE TABLE IF NOT EXISTS {sanitize_identifier(table_name)} ("]
    col_defs = [f"    {sanitize_identifier(col)} {col_types[col]}" for col in header]
    lines.append(",\n".join(col_defs))
    lines.append(");")
    return "\n".join(lines)


def generate_schema(input_dir: str, output_path: str):
    csv_files = sorted(f for f in os.listdir(input_dir) if f.lower().endswith(".csv"))

    if not csv_files:
        raise SystemExit(f"Nenhum arquivo .csv encontrado em: {input_dir}")

    statements = [
        "-- schema.sql",
        "-- Gerado automaticamente por generate_schema.py",
        "-- Tipos inferidos a partir da amostragem completa de cada CSV.",
        "",
    ]

    for csv_file in csv_files:
        table_name = os.path.splitext(csv_file)[0]
        csv_path = os.path.join(input_dir, csv_file)

        header, col_types = infer_column_types(csv_path)
        if not header:
            print(f"[aviso] {csv_file} esta vazio, pulando.")
            continue

        col_types, overrides_applied = apply_type_overrides(csv_file, header, col_types)

        create_stmt = build_create_table(table_name, header, col_types)
        statements.append(f"-- Origem: {csv_file}")
        for col, reason in overrides_applied:
            statements.append(f"-- Excecao aplicada em '{col}': {reason}")
        statements.append(create_stmt)
        statements.append("")

        print(f"[ok] {csv_file} -> tabela '{sanitize_identifier(table_name)}' "
              f"({len(header)} colunas)")

    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # O schema.sql representa o estado atual dos CSVs de origem e, portanto,
    # e regenerado integralmente a cada execucao. A evolucao de um schema
    # existente (ALTER TABLE/migracoes) esta fora do escopo deste gerador.
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(statements))

    print(f"\nSchema gerado em: {output_path}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description="Gera schema.sql (PostgreSQL) a partir de CSVs"
    )
    parser.add_argument(
        "--input", default="../data/raw",
        help="Diretorio contendo os arquivos CSV de origem (default: ../data/raw)"
    )
    parser.add_argument(
        "--output", default="../sql/schema/schema.sql",
        help="Caminho do arquivo schema.sql de saida (default: ../sql/schema/schema.sql)"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    generate_schema(args.input, args.output)