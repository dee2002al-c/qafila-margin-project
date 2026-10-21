
    

    create  table
      "qafila"."silver"."product_cost_history__dbt_tmp"
  
    
    as (
      -- Grain: one row per SKU per cost version (SCD2).
with usable as (
    select * from "qafila"."silver"."supplier_prices_checked" where reason is null
),

-- Same SKU and valid_from in several files: the file whose name sorts last wins (a _fix file).
deduplicated as (
    select sku, valid_from, unit_cost_sar
    from usable
    qualify row_number() over (partition by sku, valid_from order by source_file desc) = 1
),

-- A SKU missing from a weekly file simply has no row, so it keeps its cost.
-- A new version starts only when the cost differs from the one before.
changes as (
    select
        *,
        lag(unit_cost_sar) over (partition by sku order by valid_from) as previous_cost
    from deduplicated
),

versions as (
    select sku, unit_cost_sar, valid_from
    from changes
    where previous_cost is null or unit_cost_sar <> previous_cost
)

select
    sku,
    unit_cost_sar,
    valid_from,
    lead(valid_from) over (partition by sku order by valid_from) as valid_to,
    lead(valid_from) over (partition by sku order by valid_from) is null as is_current
from versions
    );
    
  