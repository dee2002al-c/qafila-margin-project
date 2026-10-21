# Qafila gross margin

Submitted by: Deema Alharbi — academy: @SDAIAAcademy

The task, rules and grading are in [BRIEF.md](BRIEF.md).

```bash
uv sync
uv run python tools/make_data.py          # data/
uv run python run.py                      # data/ -> warehouse/ (DuckDB + Iceberg)
uv run python tools/check.py              # contract self-check
```

> Replace every `<...>` below. Keep it short: tables and a few sentences are enough.

## Design

<A one-line flow: files → raw → staging → silver → gold → Iceberg, with the tool at each step.>

| Model | Layer | Grain (one row per ...) | Materialization |
|---|---|---|---|
| | staging | | |
| `product_cost_history` | silver | | |
| `weekly_margin` | gold | | |
| `price_quarantine` | quality | | |

**How the SCD2 history is built:** <2–3 sentences: how you handle missing weeks, unchanged costs and the correction file.>

**How each order line finds its cost:** <1–2 sentences.>

## Data problems I found

| Problem | Where | Rows affected | What I did |
|---|---|---|---|
| | | | |

## Tests

| Test | On | What it protects against |
|---|---|---|
| | | |

## Re-runs and the correction

<Show that a second run changes nothing, and that after the correction an older Iceberg snapshot still holds the old numbers: snapshot ids and one number before and after.>

## What I'd do next

<What would break first with 100× more data, or with daily supplier files?>

## AI assistance

<None, or what you used and for what.>
