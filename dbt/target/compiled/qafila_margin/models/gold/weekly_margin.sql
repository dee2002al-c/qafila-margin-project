-- Grain: one row per iso_week x city x category with at least one counted line.
-- A line counts when delivered, quantity > 0 and ordered on/after the first supplier week.
with lines as (
    select
        o.order_date,
        s.city,
        p.category,
        p.sku,
        i.quantity,
        round(i.quantity * i.unit_price - i.discount, 2) as revenue_sar
    from "qafila"."staging"."stg_order_items" as i
    inner join "qafila"."staging"."stg_orders" as o on o.order_id = i.order_id
    inner join "qafila"."staging"."stg_products" as p on p.product_id = i.product_id
    inner join "qafila"."staging"."stg_stores" as s on s.store_id = o.store_id
    where o.status = 'delivered'
      and i.quantity > 0
      and o.order_date >= date '2026-08-31'
),

-- Point in time: the cost version valid on the order date (valid_to is exclusive).
costed as (
    select
        l.*,
        h.unit_cost_sar,
        h.sku is not null as has_cost
    from lines as l
    left join "qafila"."silver"."product_cost_history" as h
        on h.sku = l.sku
       and l.order_date >= h.valid_from
       and (l.order_date < h.valid_to or h.valid_to is null)
)

select
    cast(weekofyear(order_date) as integer) as iso_week,
    city,
    category,
    cast(count(*) as integer) as lines,
    round(sum(revenue_sar), 2) as revenue_sar,
    round(coalesce(sum(revenue_sar) filter (where has_cost), 0), 2) as costed_revenue_sar,
    round(coalesce(sum(quantity * unit_cost_sar), 0), 2) as cost_sar,
    round(
        coalesce(sum(revenue_sar) filter (where has_cost), 0) - coalesce(sum(quantity * unit_cost_sar), 0), 2
    ) as margin_sar,
    cast(count(*) filter (where not has_cost) as integer) as uncosted_lines
from costed
group by 1, 2, 3