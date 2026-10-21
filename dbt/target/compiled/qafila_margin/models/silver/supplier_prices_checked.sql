-- Grain: one row per supplier file row, with the reason it is rejected (null = usable).
-- Unknown SKU is checked first, then the cost.
select
    p.source_file,
    p.sku,
    p.valid_from,
    p.raw_cost,
    round(p.parsed_cost, 2) as unit_cost_sar,
    case
        when pr.sku is null then 'unknown_sku'
        when p.parsed_cost is null or not isfinite(p.parsed_cost) or p.parsed_cost <= 0 then 'invalid_cost'
    end as reason
from "qafila"."staging"."stg_supplier_prices" as p
left join (select distinct sku from "qafila"."staging"."stg_products") as pr on pr.sku = p.sku