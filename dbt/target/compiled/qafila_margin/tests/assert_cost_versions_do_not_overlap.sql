-- A version ends exactly where the next one starts, and costs change between versions.
with v as (
    select *,
        lead(valid_from) over (partition by sku order by valid_from) as next_from,
        lead(unit_cost_sar) over (partition by sku order by valid_from) as next_cost
    from "qafila"."silver"."product_cost_history"
)
select sku from v
where valid_to is distinct from next_from or unit_cost_sar = next_cost