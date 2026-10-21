-- Grain: one row per rejected supplier row.
select source_file, sku, valid_from, raw_cost, reason
from {{ ref('supplier_prices_checked') }}
where reason is not null
