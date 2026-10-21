-- Grain: one row per product. SKU trimmed so it matches the supplier side.
select
    product_id,
    trim(sku) as sku,
    category
from "qafila"."raw"."products"