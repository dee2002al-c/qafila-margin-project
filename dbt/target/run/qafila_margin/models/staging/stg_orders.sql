
  
  create view "qafila"."staging"."stg_orders__dbt_tmp" as (
    -- Grain: one row per order. created_at is UTC; the order date is the Riyadh (UTC+3) calendar day.
select
    order_id,
    store_id,
    status,
    cast(cast(created_at as timestamp) + interval 3 hour as date) as order_date
from "qafila"."raw"."orders"
  );
