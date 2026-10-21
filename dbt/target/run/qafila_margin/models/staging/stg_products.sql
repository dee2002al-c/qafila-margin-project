
  
  create view "qafila"."staging"."stg_products__dbt_tmp" as (
    -- Grain: one row per product. SKU trimmed so it matches the supplier side.
select
    product_id,
    trim(sku) as sku,
    category
from "qafila"."raw"."products"
  );
