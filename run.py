"""Qafila gross margin pipeline: raw files -> DuckDB -> dbt -> Iceberg.

    uv run python run.py --data-dir data --warehouse warehouse

Must work on an empty warehouse folder, and must be safe to run again on the same one.
The grader runs it on a dataset you haven't seen, so never hard-code file names, row counts or SKUs.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import subprocess
import sys
from contextlib import closing
from pathlib import Path

import duckdb
import pandas as pd
from pyiceberg.catalog.sql import SqlCatalog

DBT_DIR = Path(__file__).resolve().parent / "dbt"
OLTP_TABLES = ["orders", "order_items", "products", "stores"]
# Iceberg table -> sort order (a stable row order keeps re-runs comparable)
PUBLISHED = {
    "silver.product_cost_history": "sku, valid_from",
    "gold.weekly_margin": "iso_week, city, category",
    "quality.price_quarantine": "source_file, sku, valid_from, raw_cost",
}


def get_catalog(warehouse: Path) -> SqlCatalog:
    """The Iceberg catalog the grader reads. Don't change the name, the URI or the warehouse."""
    warehouse.mkdir(parents=True, exist_ok=True)
    return SqlCatalog("qafila", uri=f"sqlite:///{(warehouse / 'catalog.db').as_posix()}", warehouse=warehouse.resolve().as_posix())


def ingest(data_dir: Path, db: Path) -> None:
    """Step 1: land the sources in DuckDB, schema `raw`, exactly as they arrive.

    - From data_dir/qafila_oltp.sqlite: orders, order_items, products, stores.
    - Every data_dir/suppliers/prices_*.csv, keeping the file name of each row.

    Running this twice must not duplicate anything: every table is rebuilt from the files.
    """
    with duckdb.connect(str(db)) as con:  # closes the file before dbt opens it
        con.sql("CREATE SCHEMA IF NOT EXISTS raw")

        with closing(sqlite3.connect(data_dir / "qafila_oltp.sqlite")) as src:
            for table in OLTP_TABLES:
                rows = pd.read_sql_query(f"SELECT * FROM {table}", src)  # noqa: S608 (fixed list)
                con.register("_rows", rows)
                con.sql(f"CREATE OR REPLACE TABLE raw.{table} AS SELECT * FROM _rows")
                con.unregister("_rows")

        # Supplier files change shape (renamed column, extra columns, BOM): read everything as text,
        # align columns by name, and let staging do the parsing.
        pattern = (data_dir / "suppliers" / "prices_*.csv").as_posix()
        con.execute(
            """
            CREATE OR REPLACE TABLE raw.supplier_prices AS
            SELECT * EXCLUDE (filename), parse_filename(filename) AS source_file
            FROM read_csv(?, all_varchar = true, union_by_name = true, filename = true)
            """,
            [pattern],
        )


def transform(db: Path) -> None:
    """Steps 2-4: build and test the dbt project in dbt/ against the DuckDB file.

    dbt runs in its own process: in this one it would keep the DuckDB file open and block publish().
    """
    env = {**os.environ, "QAFILA_DUCKDB": str(db.resolve())}
    cmd = [sys.executable, "-c", "from dbt.cli.main import cli; cli()",
           "build", "--project-dir", str(DBT_DIR), "--profiles-dir", str(DBT_DIR)]
    if subprocess.run(cmd, env=env).returncode != 0:
        raise SystemExit("dbt build failed")


def publish(db: Path, warehouse: Path) -> None:
    """Step 5: publish three dbt models to Iceberg (see the brief for the exact columns).

        silver.product_cost_history   gold.weekly_margin   quality.price_quarantine

    Update existing tables in place, never drop and recreate them: the table's snapshots are
    how we see what a number was before the supplier's correction arrived.
    """
    catalog = get_catalog(warehouse)
    with duckdb.connect(str(db), read_only=True) as con:
        for name, order_by in PUBLISHED.items():
            schema, table = name.split(".")
            new = con.sql(f"SELECT * FROM {name} ORDER BY {order_by}").to_arrow_table()  # noqa: S608
            catalog.create_namespace_if_not_exists(schema)
            if not catalog.table_exists(name):
                catalog.create_table(name, schema=new.schema).append(new)
                print(f"{name}: created ({new.num_rows} rows)")
                continue
            iceberg = catalog.load_table(name)
            current = iceberg.scan().to_arrow().select(new.schema.names).sort_by(
                [(c, "ascending") for c in new.schema.names])
            if current.cast(new.schema).equals(new.sort_by([(c, "ascending") for c in new.schema.names])):
                print(f"{name}: unchanged")  # no new snapshot on a re-run
                continue
            iceberg.overwrite(new)  # new snapshot; the old one stays readable
            print(f"{name}: updated ({new.num_rows} rows)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data-dir", type=Path, default=Path("data"))
    ap.add_argument("--warehouse", type=Path, default=Path("warehouse"))
    args = ap.parse_args()

    args.warehouse.mkdir(parents=True, exist_ok=True)
    db = args.warehouse / "qafila.duckdb"
    ingest(args.data_dir, db)
    transform(db)
    publish(db, args.warehouse)
    print(f"done: {args.warehouse.resolve()}")


if __name__ == "__main__":
    main()
