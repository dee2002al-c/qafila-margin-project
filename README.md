# Qafila Gross Margin

**Submitted by:** Deema Alharbi  
**Academy:** @SDAIAAcademy

This project implements a data engineering pipeline to calculate weekly gross margins from supplier price files and transactional order data. It includes data ingestion, transformation, SCD2 cost history, data quality validation, and Apache Iceberg table versioning.

The project requirements are documented in [BRIEF.md](BRIEF.md).

## How to Run

Run the following commands from the project root directory:

```bash
uv sync
uv run python tools/make_data.py
uv run python run.py
uv run python tools/check.py
```

To validate the pipeline using a different dataset:

```bash
uv run python tools/make_data.py --seed 11 --out data_11
uv run python run.py --data-dir data_11 --warehouse warehouse_11
uv run python tools/check.py --data-dir data_11 --warehouse warehouse_11
```

## Design

**Pipeline architecture:**

Supplier CSV files + SQLite order data → Python ingestion → DuckDB raw tables → dbt staging → SCD2 cost history (silver) → weekly margin (gold) → Apache Iceberg tables.

| Model | Layer | Grain (one row per...) | Materialization |
|---|---|---|---|
| `stg_orders` | Staging | Order | DuckDB view |
| `stg_order_items` | Staging | Order line | DuckDB view |
| `stg_products` | Staging | Product | DuckDB view |
| `stg_stores` | Staging | Store | DuckDB view |
| `product_cost_history` | Silver | SKU and effective start date | Iceberg table |
| `weekly_margin` | Gold | ISO week, city, and category | Iceberg table |
| `price_quarantine` | Quality | Rejected supplier record | Iceberg table |

**How the SCD2 history is built:** Supplier prices are processed by SKU and effective date. Missing weekly prices retain the previous known cost, while unchanged prices do not create redundant versions. Late-arriving corrections update the applicable historical cost periods, maintaining continuous, non-overlapping validity intervals.

**How each order line finds its cost:** Eligible delivered order lines are matched to the supplier cost version valid on the Riyadh order date. The matching condition uses `valid_from` inclusively and `valid_to` exclusively. Lines without a valid cost remain included in revenue and are counted as uncosted.

## Data Problems I Found

| Problem | Where | Rows affected | What I did |
|---|---|---|---|
| Invalid or non-positive supplier costs | Supplier CSV files | Included in quarantine totals | Rejected invalid costs with reason `invalid_cost` |
| Unknown product SKUs | Supplier CSV files | Included in quarantine totals | Rejected unmatched SKUs with reason `unknown_sku` |
| Late supplier price correction | Week 39 correction file | Cost history increased from 633 to 637 rows | Incorporated corrected costs into the SCD2 history |
| Missing weekly supplier prices | Supplier cost history | Not separately counted | Continued using the previously effective cost |
| Unchanged supplier prices | Supplier cost history | Not separately counted | Avoided unnecessary duplicate cost versions |

The additional Seed 11 dataset produced **7 quarantine records** across the supplier data quality checks.

## Tests

The pipeline was validated using dbt tests and the project's contract checking script.

| Test | On | What it protects against |
|---|---|---|
| Unique business keys | Staging models | Duplicate source records |
| Not-null constraints | Staging models | Missing required identifiers |
| Referential integrity | Related staging models | Invalid source relationships |
| SCD2 history checks | Cost history | Duplicate versions, gaps, and inconsistent validity periods |
| Positive cost validation | Cost history | Invalid supplier costs |
| Quarantine reason validation | Quality table | Unexpected rejection reasons |
| Weekly margin consistency | Gold table | Incorrect margin relationships |
| Source-to-output reconciliation | Weekly margin | Missing or duplicated eligible order lines |
| Iceberg snapshot validation | Gold table | Missing historical table versions |

**Validation results on Seed 11:**

| Metric | Result |
|---|---:|
| Contract checks | 22/22 passed |
| dbt tests | 20 passed |
| Cost history rows | 632 |
| Weekly margin rows | 165 |
| Quarantine rows | 7 |
| Eligible order-line reconciliation | Passed |
| Revenue reconciliation | Passed |

The contract checks validate table structure, SCD2 rules, data quality, margin consistency, and dbt test execution. Final grading may additionally compare costs and margins against expected results on an unseen dataset.

## Re-runs and the Correction

The pipeline was executed multiple times to verify reproducibility, idempotency, and late-arriving supplier corrections.

**Unchanged rerun:** Running the pipeline again without changing the input data preserved the business results.

**Week 39 correction:** Processing the late supplier correction updated the historical cost records and affected the calculated gross margin.

| Metric | Before correction | After correction |
|---|---:|---:|
| SCD2 cost history rows | 633 | 637 |
| Total margin (SAR) | 801,016.88 | 803,515.80 |

The total margin changed by **SAR 2,498.92** after processing the correction.

**Apache Iceberg snapshots:**

The `gold.weekly_margin` table retained the following three snapshots:

| Snapshot | Snapshot ID | Parent Snapshot ID |
|---|---|---|
| Snapshot 1 | `9198720270857319979` | None |
| Snapshot 2 | `540874720911920821` | `9198720270857319979` |
| Snapshot 3 | `8287781665223861300` | `540874720911920821` |

The snapshot relationships confirm that successive versions were preserved in Apache Iceberg. Earlier versions remain available for historical inspection.

The before-and-after margin values above were recorded during pipeline execution; the individual snapshot contents were not separately reconciled to those totals.

**Additional dataset:** The pipeline was also executed with Seed 11 and passed all **22/22 contract checks**, including **20 dbt tests**.

## What I'd Do Next

With 100 times more data, full-table processing and large joins could become performance bottlenecks. I would introduce incremental processing, partition pruning, optimized joins, and automated monitoring.

With daily supplier files, I would strengthen effective-date validation, late-arrival handling, and correction processing. I would also monitor quarantine volumes, data freshness, and unexpected changes in weekly margins.

## AI Assistance

AI assistance was used to understand project requirements, troubleshoot local execution issues, review Python and SQL logic, explain SCD2 and point-in-time cost matching, and help prepare project documentation.

The pipeline was executed and validated locally using the project-provided tools and checks.
