
  
  create view "qafila"."staging"."stg_order_items__dbt_tmp" as (
    -- Grain: one row per order line (order_id, line_no).
select
    order_id,
    line_no,
    product_id,
    quantity,
    unit_price,
    discount
from "qafila"."raw"."order_items"
  );
