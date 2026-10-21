# Qafila gross margin

Submitted by: Deema Alharbi — academy: @SDAIAAcademy

The project requirements are documented in [BRIEF.md](BRIEF.md).


## How to run

```bash
uv sync
uv run python tools/make_data.py
uv run python run.py
uv run python tools/check.py
```

## Design

Supplier CSV files and SQLite order data → Python ingestion → DuckDB raw tables → dbt staging → SCD2 cost history (silver) → weekly margin (gold) → Apache Iceberg tables.

| Model | Layer | Grain (one row per ...) | Materialization |
|---|---|---|---|
| `stg_orders`, `stg_order_items`, `stg_products`, `stg_stores` | staging | Source business key or order line | DuckDB views |
| `product_cost_history` | silver | SKU and effective start date | Iceberg table |
| `weekly_margin` | gold | ISO week, city and category | Iceberg table |
| `price_quarantine` | quality | Rejected supplier record | Iceberg table |

**How the SCD2 history is built:** Supplier prices are ordered by effective date for each SKU. Missing weeks retain the previous known cost, and unchanged costs do not create unnecessary versions. Late correction files update the effective cost history while maintaining non-overlapping validity periods.

**How each order line finds its cost:** Delivered order lines with positive quantities are matched to the SKU cost version valid on the Riyadh order date. Lines without a valid cost remain in revenue totals and are counted as uncosted.

## Data problems I found

| Problem | Where | What I did |
|---|---|---|
| Invalid or non-positive supplier costs | Supplier CSV files | Quarantined invalid records |
| Unknown product SKUs | Supplier CSV files | Quarantined unmatched SKUs |
| Late supplier price correction | Week 39 correction file | Updated the affected SCD2 history |
| Missing or unchanged weekly prices | Supplier price history | Preserved the previous cost without creating duplicate versions |

The additional Seed 11 dataset produced 7 quarantine records.

## Tests

| Test | On | What it protects against |
|---|---|---|
| Unique business keys | Staging models | Duplicate records |
| Not-null constraints | Staging models | Missing required identifiers |
| SCD2 version checks | Cost history | Overlapping or inconsistent versions |
| Weekly margin consistency | Gold model | Incorrect revenue and margin relationships |
| Accepted quarantine reasons | Quality model | Unexpected rejection classifications |
| Source-to-output reconciliation | Weekly margin | Missing or duplicated eligible order lines |

The project passed all 22 local contract checks, including 20 dbt tests, on the additional Seed 11 dataset.

## Re-runs and the correction

The pipeline was executed multiple times to verify reproducibility, idempotency, and late-arriving supplier corrections.

Running the pipeline again without changing the input data preserved the business results.

After applying the Week 39 supplier correction, the cost history increased from 633 to 637 records. The observed total margin changed from SAR 801,016.88 to SAR 803,515.80, reflecting the corrected historical supplier costs.

Apache Iceberg preserved three snapshots of the gold.weekly_margin table:


| Snapshot | Snapshot ID |
|---|---|
| Initial snapshot | `9198720270857319979` |
| Second snapshot | `540874720911920821` |
| Third snapshot | `8287781665223861300` |

The snapshot parent relationships confirm that each new snapshot follows the previous version. Earlier snapshots remain available for historical inspection after subsequent updates.

The pipeline was also tested using a separate dataset generated with Seed 11, passing 22/22 contract checks, including 20 dbt tests.
## What I'd do next

With 100 times more data, full-table processing and large joins could become performance bottlenecks. I would introduce incremental processing, partition pruning, and stronger monitoring.

With daily supplier files, I would improve late-arrival handling and automate validation of effective dates and corrections.

## AI assistance

AI assistance was used to explain project requirements, troubleshoot environment and execution issues, review SQL logic, and help document the implementation. The pipeline was executed and validated locally using the project-provided checks.
