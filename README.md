# Qafila Gross Margin

Submitted by: Deema Alharbi — academy: @SDAIAAcademy SDAIA Academy GitHub.

A pipeline that turns weekly supplier price files and the app database into a weekly gross-margin table that stays correct when files are re-processed or corrected. The task and rules are in [BRIEF.md](BRIEF.md).

## How to run

```bash
uv sync
uv run python tools/make_data.py              # data/
uv run python run.py                          # data/ -> warehouse/ (DuckDB + Iceberg)
uv run python tools/check.py                  # contract self-check
```

Second dataset and the late correction:

```bash
uv run python tools/make_data.py --seed 11 --out data_11
uv run python run.py --data-dir data_11 --warehouse warehouse_11
uv run python tools/check.py --data-dir data_11 --warehouse warehouse_11

uv run python tools/make_data.py --add-correction   # then run.py again
```

## Design

Supplier CSVs + SQLite → **raw** (Python + DuckDB) → **staging** (dbt views: parse, trim, Riyadh dates) → **silver** (dbt: checked prices, SCD2 history) → **gold** (dbt: weekly margin) → **Iceberg** (pyiceberg, updated in place).

| Model | Layer | Grain (one row per…) | Built as |
|---|---|---|---|
| `raw.*` | raw | source row, plus `source_file` for supplier rows | DuckDB table (rebuilt each run) |
| `stg_orders` | staging | order | view |
| `stg_order_items` | staging | order line | view |
| `stg_products` | staging | product | view |
| `stg_stores` | staging | store | view |
| `stg_supplier_prices` | staging | supplier file row | view |
| `supplier_prices_checked` | silver | supplier file row, with a rejection `reason` | table |
| `product_cost_history` | silver | SKU × cost version | table → Iceberg |
| `price_quarantine` | quality | rejected supplier row | table → Iceberg |
| `weekly_margin` | gold | iso_week × city × category | table → Iceberg |

**How the SCD2 history is built:** Rows are rejected first (`unknown_sku`, then `invalid_cost`) and ignored from then on. For the same SKU and `valid_from`, the row from the file whose name sorts last wins, so `prices_2026-W39_fix.csv` replaces `prices_2026-W39.csv`. A SKU missing from a weekly file has no row, so it keeps its previous cost; a new version starts only when the rounded cost differs from the previous one, and `valid_to` is the next version's `valid_from` (exclusive, empty for the current version).

**How each order line finds its cost:** A delivered line (quantity > 0, Riyadh order date ≥ 2026-08-31) is joined to `product_cost_history` on the trimmed SKU where `valid_from <= order_date < valid_to` (open-ended for the current version). A line with no valid version stays in `lines` and `revenue_sar` and is counted in `uncosted_lines`.

## Data problems found

Counts are from the default dataset (`data/`).

| Problem | Where | Rows | What I did |
|---|---|---:|---|
| Decimal comma (`9,49`) | W38 | 126 | converted to `9.49` |
| Arabic-Indic digits and `٫` | W38 | 34 | translated to `0-9` and `.` |
| Byte-order mark | W38 | 1 file | handled when reading the CSV |
| Renamed column `unit_cost` → `cost_sar` | W39 | 1 file | cost = `coalesce(unit_cost, cost_sar)` |
| Zero or negative cost | W39 | 4 | quarantined, `invalid_cost` |
| SKU not sold by Qafila | W39 | 3 | quarantined, `unknown_sku` |
| SKUs with trailing spaces | products | 2 | `trim` on both sides before comparing |
| Late correction file | W39 fix | 9 rows | replaces the W39 rows with the same SKU and `valid_from` |

## Tests

**dbt (20 tests, all passing):**

| Test | On | Protects against |
|---|---|---|
| `unique`, `not_null` | `stg_products`, `stg_orders` | duplicate or missing keys |
| `relationships` | `stg_order_items` → `stg_products` | order lines with an unknown product |
| `not_null` | `product_cost_history`, `weekly_margin` | missing SKU, cost, dates, city, category |
| `accepted_values` | `price_quarantine`, `supplier_prices_checked` | reasons other than `unknown_sku` / `invalid_cost` |
| `assert_one_current_version_per_sku` | `product_cost_history` | zero or several current versions |
| `assert_cost_versions_do_not_overlap` | `product_cost_history` | gaps, overlaps, repeated costs |
| `assert_margin_adds_up` | `weekly_margin` | margin ≠ costed revenue − cost, or more uncosted lines than lines |

**Contract check (`tools/check.py`, 22/22 passed on both seeds):** table columns, SCD2 rules, one row per week × city × category, and that lines and revenue cover every eligible order line. It does not know the correct costs; the grader compares those on an unseen dataset.

| Dataset | Cost history rows | Weekly margin rows | Quarantine rows |
|---|---:|---:|---:|
| default | 633 | 165 | 7 |
| `--seed 11` | 632 | 165 | 7 |

## Re-runs and the correction

**Second run on the same data:** all three tables printed `unchanged` and no new Iceberg snapshot was written.

**After `--add-correction`:** history updated from 633 to 637 rows, `weekly_margin` was updated in place, quarantine was unchanged.

`gold.weekly_margin` snapshots (total `margin_sar` read from each snapshot):

| Snapshot | Snapshot ID | Parent | Total margin (SAR) |
|---|---|---|---:|
| 1 — before the correction | `9198720270857319979` | none | 801,016.88 |
| 2 — empty step of the overwrite (delete, then append) | `540874720911920821` | `9198720270857319979` | 0.00 |
| 3 — after the correction | `8287781665223861300` | `540874720911920821` | 803,515.80 |

The older snapshot still shows the numbers from before the correction (801,016.88), while the current table shows 803,515.80, a difference of SAR 2,498.92.

## What would break first

With 100× more data, the full rebuild of every table (dbt `table`, DuckDB reload of all files, full Iceberg overwrite) would break first. I would move to incremental models, load only new files, and use an Iceberg merge instead of an overwrite. With daily supplier files, the point-in-time join and the SCD2 would need to be incremental, and quarantine volume and late corrections would need monitoring.

## AI assistance

AI assistance was used to understand project requirements, troubleshoot local execution issues, review Python and SQL logic, explain SCD2 and point-in-time cost matching, and help prepare project documentation.

The pipeline was executed and validated locally using the project-provided tools and checks.
