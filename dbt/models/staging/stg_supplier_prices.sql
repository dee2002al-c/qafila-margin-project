-- Grain: one row per row of every supplier file.
-- The cost is unit_cost, or cost_sar from week 39 on. Arabic-Indic digits (٠-٩), the Arabic
-- decimal separator (٫) and decimal commas are normalised to a plain decimal number.
with base as (
    select
        source_file,
        trim(sku) as sku,
        try_cast(valid_from as date) as valid_from,
        coalesce(unit_cost, cost_sar) as raw_cost
    from {{ source('raw', 'supplier_prices') }}
)

select
    *,
    try_cast(
        translate(trim(raw_cost), '٠١٢٣٤٥٦٧٨٩٫,', '0123456789..') as double
    ) as parsed_cost
from base
